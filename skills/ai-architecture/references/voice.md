# Voice

Decides the architecture of anything with speech in or out. Read when a feature transcribes, takes dictation or commands, or holds a spoken conversation. Vendor latency and accuracy figures are claims until measured on your own audio; current products, limits and dated measurements are in `landscape.md`.

## Which problem is it?

The three are different architectures. Pick before choosing any model.

| Mode | Shape | The hard part |
|---|---|---|
| **Transcription** of recorded audio | An async job per file | Accuracy on your audio; speakers; cost per audio hour |
| **Dictation or command**: the user speaks, the system acts or types | One-way streaming, with partial then final text | Knowing when the utterance ended; entity accuracy |
| **Conversation**: both sides speak, in real time | A duplex session with a turn-taking loop | Voice-to-voice latency; interruptions; never dead air |

**Take the cheapest mode the product allows.** Push-to-talk or an explicit "done" removes turn detection, the least reliable component. A text field beside the microphone removes the worst failures. A manual path stays for the people and places where speech does not work.

## Speech-to-text, in any mode

- **Evaluate on your own audio**, per language, accent, channel (8 kHz telephone audio is far harder than a headset) and noise level. Coverage and quality differ sharply by language, so filter providers by language first. **Word error rate hides what matters**: measure errors on the entities the product acts on (names, numbers, amounts, dates, addresses, product terms).
- **Bias the recognizer** toward your vocabulary (keyterms, a custom lexicon), and keep the list a versioned part of the release unit.
- **Generative transcribers invent text** on silence, music and noise, in published measurements about one transcript in a hundred, more as non-speech grows. Gate them with voice-activity detection, drop non-speech, and treat a low-confidence span as unknown rather than as content.
- **Check what the recognizer returns.** Some streaming models give no word timestamps, speaker labels or confidence; if the product needs one, that is a selection criterion.
- **Partial transcripts change.** Only final text may trigger an action; partials drive the display and may warm up downstream work.
- **Mixed-language speech** (switching language mid-sentence) and domain jargon fail quietly: put both in the eval set if users do either.
- **Keep the raw transcript** when a model cleans it up; the cleaned text is derived data and can be wrong in new ways.
- **On-device recognition** buys privacy, offline use, zero marginal cost and low latency. Ask for it explicitly: a platform's default recognizer may send audio to a server. A common split is local partials for the interface and a server pass for the final text (`on-device.md`).

## Text-to-speech

What the user hears is this stage, so it carries as much of the product as the model behind it. Put it behind a port: text stream in, audio out, cancel, timestamps where offered.

- **The voice is a product decision that is hard to reverse.** People attach to a voice. A cloned voice cannot be exported and a re-clone elsewhere sounds different, and stock voices, models and whole vendors disappear on short notice. Own the source recordings and the speaker's consent, pin the voice id and model version in the release unit, keep a second vendor wired, and name the fallback voice before an outage chooses it for you.
- **It has to start before the sentence is finished.** Taking text incrementally as the model generates it is a property of a specific model, not of a vendor: choose one that does, or buffer to sentence boundaries. Fragments that are too small make speech choppy and missing punctuation distorts it, so the adapter owns the chunking and flushes at the end of the turn. Vendors quote server-side medians; budget from your own p95 to the first audible sample on the real channel.
- **It must report where it is.** Timestamps in the audio stream are a selection criterion, since some synthesizers return none. The playout edge owns the clock: commit to history only the text confirmed played.
- **Evaluate per language on your own script.** Naturalness is the easy part. The errors that matter are names, numbers, addresses, loanwords and sentences that mix languages. Keep the pronunciation lexicon as a versioned part of the release unit. Markup support is shrinking on newer engines: express intent neutrally and let each adapter render what its engine accepts.
- **Own the normalization, and test it per engine.** Numbers, dates, currency, units and abbreviations become words in code before synthesis, per language, with a regression set. Engines normalize only some languages, language-specific forms (counters, registers of politeness) are rarely covered, and on some engines heavy pre-processing makes the output worse.
- **Neural synthesis can say the wrong words**, and vendors do not promise otherwise. Keep chunks short. For values that matter (amounts, dates, names) use a template or a pre-rendered clip, confirm on a second channel, and check in the eval by transcribing the output and comparing the entities.
- **Synthesize fixed phrases ahead of time**: greetings, disclosures, acknowledgements and stored answers. Re-synthesis is not deterministic, so cache the audio itself, keyed by text, voice, model version, settings and audio format. Cached phrases play with no model in the path and cost nothing per call.
- **Cost is per character, per audio token or per minute.** A talkative prompt is paid for twice, in the model and here, and heard as delay.
- **The channel changes the voice.** Synthesize in the telephone's own narrowband format and judge the voice there, not on studio speakers.
- **Generated speech is synthetic media.** Say by voice that it is AI at the start, keep the provenance marks vendors embed in the audio, store cloning consent with the voice, and never read arbitrary user-supplied text in a cloned voice.
- **On-device voices** from the platform are free, offline, less natural, and report word positions: the fallback when the network or the provider is down, and the default where audio must not leave the device. Open on-device neural voices cover few languages.

## Transcription jobs

Upload to object storage, process as a job with progress, store text with timestamps. Long files are chunked on silence, not on a fixed length. Cost is per audio hour, so the envelope's binding unit is audio minutes per day and the peak is concurrent audio. Audio and transcript get separate retention: the audio is usually the more sensitive and can often be deleted once the transcript is verified.

## Conversation: three shapes

| Shape | How | Choose when | Pays |
|---|---|---|---|
| **Cascade** | Speech-to-text → a text model → text-to-speech, streaming between stages | The agent must act (tools, records, payments); a transcript of what the model reasoned over is required; a specific voice; a language only some parts cover; parts must be swappable | A hop per stage; prosody and emotion are lost at the text boundary |
| **Speech-to-speech** | One model, audio in and audio out | Natural rhythm and expressiveness matter most; the conversation is the product | A voice fixed for the session and limited to what the model offers; transcripts are a side output; harder to debug, audit and constrain; weaker at calling tools |
| **Delegated** | A speech model holds the conversation and hands reasoning and tool calls to a text model behind it | Both a natural voice and dependable tool use; the user should be able to keep talking while work runs | Two models to pay for and keep consistent |

**When a call must reliably trigger tools, keep a text model in the loop.** In a public benchmark, text models completed required tool calls almost every time while speech-to-speech models omitted a meaningful share of them. Do not assume speech-to-speech is faster either: measured medians overlap. Own the turn-taking state machine, the tool layer and the transcript store, keep speech models behind adapters, and the choice of shape stays reversible. Whichever shape, **tool calls stall the conversation**: speak a short acknowledgement before a slow call, and never leave silence longer than the budget.

## Latency budget

Voice-to-voice delay is what the caller hears: end of their speech to the first sound of the reply.

**delay = end-of-turn wait + final transcript + first token of the reply + first audio + network hops**

- **A target names its clock, its percentile and its channel.** Measured at the listener's ear, a median near one second in an app and about a second and a half on a phone call are workable targets, and two seconds of silence is where callers give up. People answer each other in a few hundred milliseconds; measured production phone agents sit above a second at the median and around two at p95, so test before promising a number.
- **End-of-turn detection is layered**: a silence timer as the backstop, a model that judges whether the utterance is complete, and optionally a speculative start on a "probably done" signal that is cancelled if the speaker resumes. Each layer has a price: the speculative start buys a hundred milliseconds or two for half again as many model calls, and a detector that waits for a whole phone number or address cuts entity errors while lengthening the tail. Choose per product, and pick detectors that support the language.
- **Stream every stage**: partial text into the model, the first sentence into speech synthesis while the rest generates. The model's first token is usually the largest and least predictable stage.
- **Co-locate** the stages and the media server in the user's region; each cross-region hop is spent budget.
- **Instrument per stage** so a slow turn is attributable to detection, recognition, generation, synthesis or network.

## Turn-taking is a state machine you own

States: listening · user speaking · thinking · speaking · interrupted. Code owns the transitions; the model does not.

- **Interruption (barge-in)** cancels synthesis and the in-flight generation, and stops billing.
- **Whoever owns the playback buffer truncates the history.** After an interruption the conversation record keeps only the part of the reply that was actually played. A provider that carries the media can do this itself; when your server bridges audio over a plain socket, the client must report the played position and you truncate. Otherwise the model believes it said things the user never heard.
- **False interruptions** (a cough, "mm-hm", the agent's own voice echoing back) need echo cancellation and a classifier that tells a backchannel from a real interruption: a decision-tier question.
- **Silence, overlap and "are you there?"** are designed states with timeouts, not accidents.

## Sessions, transport and capacity

- **A conversation is a stateful, long-lived session**, usually one process per call. Capacity is concurrent sessions, not requests per second. Deploys drain for longer than the longest call instead of killing calls.
- **Provider sessions end.** Speech APIs cap a session at minutes to an hour: keep the conversation state in your own store and build resume across sessions first, not after the first dropped call.
- **Transport**: from a browser or phone app to your media edge, use a real-time media transport (packet-loss tolerant, with jitter buffering and echo cancellation); a plain socket is acceptable between servers. Telephone calls arrive as 8 kHz narrowband audio through a carrier: transfers need signaling control, keypad tones arrive as events, and the phone number, the carrier and recording duties are their own decisions.
- **Each stage is a dependency** with a deadline and a degraded mode: a fallback recognizer or voice, pre-recorded phrases, a text path, or a warm transfer to a person with the transcript attached.
- **Cost is per minute** of conversation, across every stage: put it in the envelope per successful call, tail included.

## Spoken output is its own contract

- **Write for the ear**: short sentences, no markup, no lists read aloud. The prompt asks for speakable text; code enforces it.
- **Read back and confirm critical entities** (amounts, dates, names, addresses), spelled or digit by digit where needed. Structured data is captured through a tool call with typed arguments, never parsed back out of speech.
- **Refusals, limits and hand-offs** have spoken forms.

## Trust

- **Say that the caller is talking to an AI** when the conversation starts; several jurisdictions now require notice (`landscape.md`).
- **Recording law depends on the country and on who counts as a party to the call.** Ask the caller for the regime and have counsel confirm consent and notice duties before recording or retaining audio.
- **Audio is personal data, and a voice can identify a person**: classify it, minimize retention, and keep it out of logs and eval sets without a basis.
- **Speech is an injection channel.** Whatever the recognizer produces is untrusted input, including speech played at the microphone by a third party.
- **Never authenticate a person by voice alone.** Synthetic voices are cheap.

## Evals

Three layers: text-only regression of the conversation logic (cheap, on every change); simulated callers over real audio conditions (noise, accents, interruptions, long pauses, mixed language); and timing from recorded real calls, with consent. Per stage: false cut-offs and end-of-turn latency; recognition entity error rate; pronunciation errors on an entity list and time to first audio for synthesis; task completion; voice-to-voice median and p95, on turns with and without tool calls; interruption handling; tool-call correctness. The gate runs on the full pipeline, since each stage's errors compound in the next.

## Red flags

- 🔴 An action taken on a partial transcript, or a spoken amount acted on without read-back.
- 🔴 A feature that records or clones voices with no consent path.
- 🟠 A latency number with no clock, percentile or channel, or measured without tool-call turns.
- 🟠 Conversation history that includes speech the user interrupted before hearing.
- 🟠 A speech-to-speech model as the only path to a tool that must not be skipped.
- 🟠 No resume when the provider's session limit ends a call.
- 🟠 Recognition validated on clean studio audio or on word error rate alone; a voice chosen on a demo sentence.
- 🟠 A custom voice on one vendor with no recorded exit, or no fallback voice.
- 🟠 Deploys that drop live calls, or capacity planned in requests per second.
