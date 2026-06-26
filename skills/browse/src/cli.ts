/**
 * browse CLI — thin wrapper that talks to the persistent server
 *
 * Flow:
 *   1. Read .browse/browse.json for port + token
 *   2. If missing or stale PID → start server in background
 *   3. Health check + version mismatch detection
 *   4. Send command via HTTP POST
 *   5. Print response to stdout (or stderr for errors)
 */

import * as fs from 'fs';
import * as path from 'path';
import { resolveConfig, ensureStateDir, readVersionHash } from './config';

const config = resolveConfig();
const MAX_START_WAIT = 8000; // 8 seconds to start

export function resolveServerScript(
  env: Record<string, string | undefined> = process.env,
  metaDir: string = import.meta.dir,
  execPath: string = process.execPath
): string {
  if (env.BROWSE_SERVER_SCRIPT) {
    return env.BROWSE_SERVER_SCRIPT;
  }

  // Dev mode: cli.ts runs directly from browse/src
  if (metaDir.startsWith('/') && !metaDir.includes('$bunfs')) {
    const direct = path.resolve(metaDir, 'server.ts');
    if (fs.existsSync(direct)) {
      return direct;
    }
  }

  // Compiled binary: derive the source tree from browse/dist/browse
  if (execPath) {
    const adjacent = path.resolve(path.dirname(execPath), '..', 'src', 'server.ts');
    if (fs.existsSync(adjacent)) {
      return adjacent;
    }
  }

  throw new Error(
    'Cannot find server.ts. Set BROWSE_SERVER_SCRIPT env or run from the browse source tree.'
  );
}

const SERVER_SCRIPT = resolveServerScript();

interface ServerState {
  pid: number;
  port: number;
  token: string;
  startedAt: string;
  serverPath: string;
  binaryVersion?: string;
}

// ─── State File ────────────────────────────────────────────────
function readState(): ServerState | null {
  try {
    const data = fs.readFileSync(config.stateFile, 'utf-8');
    return JSON.parse(data);
  } catch {
    return null;
  }
}

function isProcessAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

// ─── Process Management ─────────────────────────────────────────
async function killServer(pid: number): Promise<void> {
  if (!isProcessAlive(pid)) return;

  try { process.kill(pid, 'SIGTERM'); } catch { return; }

  // Wait up to 2s for graceful shutdown
  const deadline = Date.now() + 2000;
  while (Date.now() < deadline && isProcessAlive(pid)) {
    await Bun.sleep(100);
  }

  // Force kill if still alive
  if (isProcessAlive(pid)) {
    try { process.kill(pid, 'SIGKILL'); } catch {}
  }
}

/**
 * Clean up legacy /tmp/browse-server*.json files from before project-local state.
 * Verifies PID ownership before sending signals.
 */
function cleanupLegacyState(): void {
  try {
    const files = fs.readdirSync('/tmp').filter(f => f.startsWith('browse-server') && f.endsWith('.json'));
    for (const file of files) {
      const fullPath = `/tmp/${file}`;
      try {
        const data = JSON.parse(fs.readFileSync(fullPath, 'utf-8'));
        if (data.pid && isProcessAlive(data.pid)) {
          // Verify this is actually a browse server before killing
          const check = Bun.spawnSync(['ps', '-p', String(data.pid), '-o', 'command='], {
            stdout: 'pipe', stderr: 'pipe', timeout: 2000,
          });
          const cmd = check.stdout.toString().trim();
          if (cmd.includes('bun') || cmd.includes('server.ts')) {
            try { process.kill(data.pid, 'SIGTERM'); } catch {}
          }
        }
        fs.unlinkSync(fullPath);
      } catch {
        // Best effort — skip files we can't parse or clean up
      }
    }
    // Clean up legacy log files too
    const logFiles = fs.readdirSync('/tmp').filter(f =>
      f.startsWith('browse-console') || f.startsWith('browse-network') || f.startsWith('browse-dialog')
    );
    for (const file of logFiles) {
      try { fs.unlinkSync(`/tmp/${file}`); } catch {}
    }
  } catch {
    // /tmp read failed — skip legacy cleanup
  }
}

// ─── Server Lifecycle ──────────────────────────────────────────
async function startServer(): Promise<ServerState> {
  ensureStateDir(config);

  // Clean up stale state file
  try { fs.unlinkSync(config.stateFile); } catch {}

  // Start server as detached background process
  const proc = Bun.spawn(['bun', 'run', SERVER_SCRIPT], {
    stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, BROWSE_STATE_FILE: config.stateFile },
  });

  // Don't hold the CLI open
  proc.unref();

  // Wait for state file to appear
  const start = Date.now();
  while (Date.now() - start < MAX_START_WAIT) {
    const state = readState();
    if (state && isProcessAlive(state.pid)) {
      return state;
    }
    await Bun.sleep(100);
  }

  // If we get here, server didn't start in time
  // Try to read stderr for error message
  const stderr = proc.stderr;
  if (stderr) {
    const reader = stderr.getReader();
    const { value } = await reader.read();
    if (value) {
      const errText = new TextDecoder().decode(value);
      throw new Error(`Server failed to start:\n${errText}`);
    }
  }
  throw new Error(`Server failed to start within ${MAX_START_WAIT / 1000}s`);
}

// Health check: an HTTP /health 200 is definitive proof the daemon is alive and
// responsive — more reliable than process.kill(pid,0), which a recycled PID passes.
async function isServerHealthy(port: number): Promise<boolean> {
  try {
    const resp = await fetch(`http://127.0.0.1:${port}/health`, {
      signal: AbortSignal.timeout(2000),
    });
    if (!resp.ok) return false;
    const health = await resp.json() as any;
    return health.status === 'healthy';
  } catch {
    return false;
  }
}

/**
 * Acquire an exclusive lockfile so concurrent ensureServer() calls can't BOTH spawn a
 * daemon — a TOCTOU race that leaves orphaned headless Chromium zombies reaped only by
 * the 30-min idle timer. Ported from gstack browse (acquireServerLock, landed v0.11.1.0).
 * Returns a release fn, or null if another *live* process already holds the lock.
 */
function acquireServerLock(): (() => void) | null {
  const lockPath = `${config.stateFile}.lock`;
  try {
    // 'wx' — create exclusively, fail if it already exists (atomic check-and-create).
    // String flag (not numeric fs.constants) for Bun compiled-binary compatibility.
    const fd = fs.openSync(lockPath, 'wx');
    fs.writeSync(fd, `${process.pid}\n`);
    fs.closeSync(fd);
    return () => { try { fs.unlinkSync(lockPath); } catch {} };
  } catch {
    // Lock already held — clear it only if we can prove the holder is gone, then retry.
    try {
      const raw = fs.readFileSync(lockPath, 'utf8').trim();
      const holderPid = parseInt(raw, 10);
      if (Number.isNaN(holderPid)) {
        // The file exists but has no PID yet: the winner created it with 'wx' and is
        // mid-init (writeSync of its PID is the very next sync call). Treat a FRESH
        // empty lock as a live holder and wait — do NOT unlink it, or we'd race the
        // winner and both daemons would start. Only reap a long-stale empty lock left
        // by a holder that crashed in that microsecond window.
        const ageMs = Date.now() - fs.statSync(lockPath).mtimeMs;
        if (ageMs < 10_000) return null;
        fs.unlinkSync(lockPath);
        return acquireServerLock();
      }
      if (isProcessAlive(holderPid)) {
        return null; // another live process is starting the server
      }
      fs.unlinkSync(lockPath); // stale lock from a dead holder
      return acquireServerLock();
    } catch {
      return null;
    }
  }
}

async function ensureServer(): Promise<ServerState> {
  const state = readState();

  // Health-check-first: HTTP is definitive, and skips the PID-reuse stall where a
  // recycled PID passes isProcessAlive() and wastes the full health timeout.
  if (state && await isServerHealthy(state.port)) {
    // Binary version mismatch → auto-restart on update (falls through to locked start).
    const currentVersion = readVersionHash();
    if (!(currentVersion && state.binaryVersion && currentVersion !== state.binaryVersion)) {
      return state;
    }
    console.error('[browse] Binary updated, restarting server...');
    await killServer(state.pid);
  }

  // Need to (re)start — serialize via an exclusive lock so two CLIs that both find no
  // healthy server don't each spawn a daemon (orphaned Chromium zombies).
  ensureStateDir(config);
  const releaseLock = acquireServerLock();
  if (!releaseLock) {
    // Another instance is starting the server — wait for it instead of spawning a rival.
    console.error('[browse] Another instance is starting the server, waiting...');
    const startedWaiting = Date.now();
    while (Date.now() - startedWaiting < MAX_START_WAIT) {
      const fresh = readState();
      if (fresh && await isServerHealthy(fresh.port)) return fresh;
      await Bun.sleep(200);
    }
    throw new Error('Timed out waiting for another instance to start the server');
  }

  try {
    // Re-read under the lock in case another process started the server first.
    const fresh = readState();
    if (fresh && await isServerHealthy(fresh.port)) return fresh;

    // Kill the old (unhealthy/superseded) server to avoid orphaned Chromium.
    if (state && state.pid) await killServer(state.pid);

    console.error('[browse] Starting server...');
    return startServer();
  } finally {
    releaseLock();
  }
}

// ─── Command Dispatch ──────────────────────────────────────────
async function sendCommand(state: ServerState, command: string, args: string[], retries = 0): Promise<void> {
  const body = JSON.stringify({ command, args });

  try {
    const resp = await fetch(`http://127.0.0.1:${state.port}/command`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${state.token}`,
      },
      body,
      signal: AbortSignal.timeout(30000),
    });

    if (resp.status === 401) {
      // Token mismatch — server may have restarted
      console.error('[browse] Auth failed — server may have restarted. Retrying...');
      const newState = readState();
      if (newState && newState.token !== state.token) {
        return sendCommand(newState, command, args);
      }
      throw new Error('Authentication failed');
    }

    const text = await resp.text();

    if (resp.ok) {
      process.stdout.write(text);
      if (!text.endsWith('\n')) process.stdout.write('\n');
    } else {
      // Try to parse as JSON error
      try {
        const err = JSON.parse(text);
        console.error(err.error || text);
        if (err.hint) console.error(err.hint);
      } catch {
        console.error(text);
      }
      process.exit(1);
    }
  } catch (err: any) {
    if (err.name === 'AbortError') {
      console.error('[browse] Command timed out after 30s');
      process.exit(1);
    }
    // Connection error — server may have crashed
    if (err.code === 'ECONNREFUSED' || err.code === 'ECONNRESET' || err.message?.includes('fetch failed')) {
      if (retries >= 1) throw new Error('[browse] Server crashed twice in a row — aborting');
      console.error('[browse] Server connection lost. Restarting...');
      const newState = await startServer();
      return sendCommand(newState, command, args, retries + 1);
    }
    throw err;
  }
}

// ─── Main ──────────────────────────────────────────────────────
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log(`browse — Fast headless browser for AI coding agents

Usage: browse <command> [args...]

Navigation:     goto <url> | back | forward | reload | url
Content:        text | html [sel] | links | forms | accessibility
Interaction:    click <sel> | fill <sel> <val> | select <sel> <val>
                hover <sel> | type <text> | press <key>
                scroll [sel] | wait <sel|--networkidle|--load|--domcontentloaded> [timeoutMs] | viewport <WxH>
                upload <sel> <file1> [file2...]
                cookie-import <json-file>
                cookie-import-browser [browser] [--domain <d>]
Inspection:     js <expr> | eval <file> | css <sel> <prop> | attrs <sel>
                console [--clear|--errors] | network [--clear] | dialog [--clear]
                cookies | storage [set <k> <v>] | perf
                is <prop> <sel> (visible|hidden|enabled|disabled|checked|editable|focused)
Visual:         screenshot [--viewport] [--clip x,y,w,h] [@ref|sel] [path]
                pdf [path] | responsive [prefix]
Snapshot:       snapshot [-i] [-c] [-d N] [-s sel] [-D] [-a] [-o path] [-C]
                -D/--diff: diff against previous snapshot
                -a/--annotate: annotated screenshot with ref labels
                -C/--cursor-interactive: find non-ARIA clickable elements
Compare:        diff <url1> <url2>
Multi-step:     chain (reads JSON from stdin)
Tabs:           tabs | tab <id> | newtab [url] | closetab [id]
Server:         status | cookie <n>=<v> | header <n>:<v>
                useragent <str> | stop | restart
Dialogs:        dialog-accept [text] | dialog-dismiss

Refs:           After 'snapshot', use @e1, @e2... as selectors:
                click @e3 | fill @e4 "value" | hover @e1
                @c refs from -C: click @c1`);
    process.exit(0);
  }

  // One-time cleanup of legacy /tmp state files
  cleanupLegacyState();

  const command = args[0];
  const commandArgs = args.slice(1);

  // Lifecycle commands are process management — handle them directly via signals
  // rather than over HTTP. Sending 'stop'/'restart' as HTTP commands races the
  // server's process.exit() against the response, dropping it and tripping the
  // reconnect-on-disconnect path in sendCommand (which would restart the very
  // server we are trying to stop).
  if (command === 'stop' || command === 'restart') {
    const existing = readState();
    if (existing && isProcessAlive(existing.pid)) {
      await killServer(existing.pid); // SIGTERM → graceful shutdown, then SIGKILL
    }
    // Clear state even if an older daemon died without cleaning up after itself.
    try { fs.unlinkSync(config.stateFile); } catch {}
    if (command === 'stop') {
      process.stdout.write('Server stopped\n');
    } else {
      const fresh = await startServer();
      process.stdout.write(`Server restarted (PID: ${fresh.pid})\n`);
    }
    return;
  }

  // Special case: chain reads from stdin
  if (command === 'chain' && commandArgs.length === 0) {
    const stdin = await Bun.stdin.text();
    commandArgs.push(stdin.trim());
  }

  const state = await ensureServer();
  await sendCommand(state, command, commandArgs);
}

if (import.meta.main) {
  main().catch((err) => {
    console.error(`[browse] ${err.message}`);
    process.exit(1);
  });
}
