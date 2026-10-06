# Generative AI Tools for Ad Creative

AI tools for generating ad images, videos, and audio at scale.

---

## Table of Contents

1. [Image Generation](#image-generation)
2. [Video Generation](#video-generation)
3. [Voice & Audio](#voice--audio)
4. [Code-Based Video (Remotion)](#code-based-video-remotion)
5. [Batch Creative Production Workflow](#batch-creative-production-workflow)
6. [Quality Control Checklist](#quality-control-checklist)

---

## Image Generation

### Tools Comparison

| Tool | Best For | Quality | Cost |
|------|----------|---------|------|
| **Gemini (Nano Banana Pro)** | Quick iterations, product mockups | High | Low (API pricing) |
| **Flux (Black Forest Labs)** | Photorealistic, text-in-image | Very High | Medium |
| **Ideogram** | Text rendering, logos | High (text) | Medium |
| **Midjourney** | Artistic, lifestyle imagery | Very High | $10-120/mo (Basic→Mega) |
| **GPT Image** (OpenAI, `gpt-image-2` or newer) | Conceptual, illustrative, strong in-image text | High | API pricing |

> Note: DALL·E 3 was removed from the OpenAI API on **May 12, 2026**, and `gpt-image-1.5` /
> `gpt-image-1-mini` shut down on **Dec 1, 2026** — use `gpt-image-2` or a newer GPT Image
> model (check OpenAI's deprecations page for the current recommended ID).

### Image Generation Workflow

1. **Brief**: Define the visual concept (scene, style, mood, text elements)
2. **Prompt**: Write detailed prompt with style, composition, and brand cues
3. **Generate**: Create 4-8 variations
4. **Select**: Pick top 2-3 candidates
5. **Refine**: Inpaint, upscale, or regenerate with adjusted prompts
6. **Resize**: Adapt to platform-specific dimensions
7. **Brand overlay**: Add logo, CTA button, legal text in design tool

### Prompting Tips for Ad Images
- Specify aspect ratio matching your ad placement
- Include brand colors in the prompt
- Mention "advertising" or "marketing material" for commercial styling
- Be specific about composition: "product centered, white background"
- Use negative prompts to avoid: text errors, brand confusion, inappropriate content
- Generate at highest resolution, then crop/resize

### Platform Image Dimensions

| Placement | Dimensions | Ratio |
|-----------|-----------|-------|
| Meta Feed (square) | 1080×1080 | 1:1 |
| Meta Feed (portrait) | 1080×1350 | 4:5 |
| Meta/TikTok Stories | 1080×1920 | 9:16 |
| Google Display | 1200×628 | 1.91:1 |
| LinkedIn | 1200×627 | 1.91:1 |
| X (Twitter) | 1200×675 | 16:9 |

---

## Video Generation

### Tools Comparison

| Tool | Best For | Duration | Quality |
|------|----------|----------|---------|
| **Veo (Google)** | Realistic scenes, product demos | Up to 8s/clip | Very High |
| **Kling 3.0** | Motion, action sequences | Up to 15s native (longer via Extend) | Very High |
| **Runway Gen-4 / Gen-4.5** | Creative control, world/character consistency | ~10s/clip | High |
| **Seedance 2.0** (ByteDance) | Narrative/cinematic video + synced audio | Up to 15s | Very High |
| **Higgsfield** | Character-driven, social style | Up to 10s | Medium-High |

> Durations are single-clip native limits as of mid-2026 and move fast — verify against
> the vendor before quoting to a client. OpenAI's Videos API and all Sora 2 models were shut
> down on Sep 24, 2026, with no API replacement named (as of 2026-10).

### Video Ad Workflow

1. **Script**: Write the ad script (hook → value → CTA)
2. **Storyboard**: Plan 3-5 key scenes
3. **Generate clips**: Create individual scenes with AI
4. **Edit**: Combine clips, add transitions, text overlays
5. **Audio**: Add voiceover, music, sound effects
6. **Format**: Export in required aspect ratios (16:9, 9:16, 1:1)
7. **Thumbnail**: Generate or extract key frame

### AI Video Best Practices
- Keep AI-generated clips to 3-8 seconds each
- Use cuts between clips to hide inconsistencies
- Add text overlays to reinforce messaging
- Combine AI footage with real product screenshots/recordings
- Test AI vs. human-shot creative — results vary by audience

---

## Voice & Audio

### Tools Comparison

| Tool | Best For | Features |
|------|----------|----------|
| **ElevenLabs** | Most natural TTS, voice cloning | 70+ languages (Eleven v3), cloning, dubbing |
| **OpenAI TTS** | Simple voiceover, API integration | 13 built-in steerable voices (`gpt-4o-mini-tts`), streaming, affordable |
| **Cartesia** | Low-latency, real-time | Fast generation, emotion control |
| **Murf** | Commercial voiceover | Brand voice consistency |

### Voiceover Workflow

1. **Script**: Write ad script optimized for listening (short sentences, conversational)
2. **Voice selection**: Choose voice matching brand personality
3. **Generate**: Create voiceover with TTS tool
4. **Review**: Check pronunciation, pacing, emphasis
5. **Refine**: Adjust speed, tone, pauses
6. **Mix**: Combine with background music and sound effects

### Voice Cloning Considerations
- Get explicit consent from the person being cloned
- Review platform policies (some prohibit cloned voices in ads)
- Maintain consistency — use the same cloned voice across campaigns
- Keep a library of approved voice profiles

### Multilingual Production
- ElevenLabs supports 70+ languages (Eleven v3) with natural accent preservation
- Generate same ad in multiple languages from one script
- Review with native speakers — AI translation isn't perfect
- Adjust timing — some languages are longer/shorter

---

## Code-Based Video (Remotion)

### What It Is
Remotion is a React framework for creating videos programmatically. Ideal for templated, data-driven ad production at scale.

### When to Use
- You need 50+ ad variations with different text/data
- You have a winning ad format you want to scale
- You need consistent brand templates across campaigns
- You want to automate video production from data feeds

### Workflow

```
1. Design hero creative with AI tools (exploratory)
2. Identify winning patterns from performance data
3. Build Remotion template based on winning structure
4. Feed data (headlines, images, prices) into template
5. Batch render all variations
6. Upload to ad platforms
```

### Remotion Ad Template Structure

```
src/
├── compositions/
│   ├── ProductAd.tsx       # Main ad composition
│   ├── TestimonialAd.tsx   # Testimonial format
│   └── ComparisonAd.tsx    # A vs B format
├── components/
│   ├── AnimatedText.tsx    # Text animations
│   ├── ProductShot.tsx     # Product image handling
│   ├── CTAButton.tsx       # Call-to-action animation
│   └── Logo.tsx            # Brand logo placement
├── data/
│   └── variations.json     # All ad variations data
└── render.ts               # Batch rendering script
```

### Cost for Scaled Production

| Method | 100 Ad Variations | 500 Variations |
|--------|-------------------|----------------|
| AI Image (Flux) | ~$10-20 | ~$50-100 |
| AI Video (Kling) | ~$50-100 | ~$250-500 |
| Remotion (video from template) | ~$5-10 (compute) | ~$20-50 |
| Voiceover (ElevenLabs) | ~$5-15 | ~$25-75 |
| Manual design | $500-2,000 | $2,500-10,000 |

---

## Batch Creative Production Workflow

### Phase 1: Exploration (AI-Heavy)
- Generate diverse concepts with AI image/video tools
- Test 5-10 visually different approaches
- Don't optimize yet — explore widely

### Phase 2: Validation (Performance Data)
- Run top concepts as ads for 1-2 weeks
- Collect performance data (CTR, conversion, ROAS)
- Identify winning visual patterns and themes

### Phase 3: Scale (Template-Heavy)
- Build Remotion templates from winning patterns
- Create variation matrix:

| Variable | Options |
|----------|---------|
| Headline | 5 variations |
| Image | 3 variations |
| CTA | 2 variations |
| Color scheme | 2 variations |
| **Total** | **60 combinations** |

- Batch render all combinations
- Upload to platform for algorithmic optimization

### Phase 4: Iterate
- Review performance weekly
- Retire bottom 20% of creatives
- Generate new variations of top 20%
- Test 1-2 new concepts each cycle
- Refresh before fatigue — cadence is platform-specific (TikTok ~weekly, Meta bi-weekly, Google/LinkedIn 4-6 weeks); see `creative-testing.md` fatigue tables

---

## Quality Control Checklist

Before launching AI-generated creative:

- [ ] No AI artifacts (weird hands, distorted text, inconsistent objects)
- [ ] Brand colors and logo correctly placed
- [ ] Text is legible at mobile sizes
- [ ] No copyrighted material inadvertently generated
- [ ] Meets platform ad policies (no misleading imagery)
- [ ] Correct aspect ratios for all placements
- [ ] Legal disclaimers included where required
- [ ] Voiceover pronunciation is correct
- [ ] Video has captions/subtitles (most social video is watched muted)
- [ ] File sizes within platform limits
