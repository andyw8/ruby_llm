# HuggingFace Inference Providers — Implementation Plan

## What the HF Inference Providers API is

It's a **routing proxy** that sits in front of multiple backends (Groq, Together, Fal, Replicate, Fireworks, etc.) behind a single unified API. Authentication is a single HF token. The key insight is: **for chat completions it's fully OpenAI-compatible** — just `https://router.huggingface.co/v1`. For other tasks (image generation, embeddings, speech) it uses HF-specific endpoints.

---

## Implementation approach

### The easy path (chat only): subclass `OpenAI`

The HF router is a drop-in OpenAI-compatible endpoint. Like `Mistral` and `OpenRouter`, you'd get ~80% for free:

```ruby
# lib/ruby_llm/providers/hugging_face.rb
class HuggingFace < OpenAI
  include HuggingFace::Chat
  include HuggingFace::Models

  def api_base
    'https://router.huggingface.co/v1'
  end

  def headers
    { 'Authorization' => "Bearer #{@config.hugging_face_api_key}" }
  end
end
```

The HF model naming convention — `"owner/model-name:policy"` (e.g., `"meta-llama/Llama-3.1-8B-Instruct:fastest"`) — is slightly different from typical model IDs, so `HuggingFace::Chat` would need to handle that.

### The harder path: non-chat tasks

For **embeddings** and **image generation**, HF doesn't use the OpenAI-compatible router — they have their own task-specific endpoint format (e.g., `POST https://router.huggingface.co/hf-inference/models/{model_id}/v1/embeddings`). This would require custom `Embeddings` and `Images` modules similar to the Gemini ones.

---

## Files to create/modify

| File | What | Complexity |
|---|---|---|
| `lib/ruby_llm/providers/hugging_face.rb` | Main provider class | Low |
| `lib/ruby_llm/providers/hugging_face/chat.rb` | Handle model ID format + provider suffix | Low |
| `lib/ruby_llm/providers/hugging_face/models.rb` | Fetch from `https://huggingface.co/api/models?inference_provider=all` | Medium |
| `lib/ruby_llm/providers/hugging_face/capabilities.rb` | Map HF `pipeline_tag` → capabilities | Medium |
| `lib/ruby_llm/providers/hugging_face/embeddings.rb` | HF-specific embeddings endpoint | Medium |
| `lib/ruby_llm/providers/hugging_face/images.rb` | HF-specific text-to-image endpoint | Medium |
| `lib/ruby_llm/configuration.rb` | Add `hugging_face_api_key` attr | Trivial |
| `lib/ruby_llm.rb` | Register the provider | Trivial |

---

## Key design challenges

1. **Model registry**: HF has thousands of models. The `models.json` auto-generation rake task would need to fetch from `https://huggingface.co/api/models?inference_provider=all` and normalise HF's `pipeline_tag` (e.g., `text-generation`, `text-to-image`, `feature-extraction`) into ruby_llm's capability system.

2. **Model ID format**: HF models are `owner/repo` (e.g., `meta-llama/Llama-3.1-8B-Instruct`) and can have a provider suffix (`:fastest`, `:cheapest`, `:sambanova`). The chat payload would need to pass the full ID through.

3. **Non-chat tasks use different base URLs**: Image gen and embeddings hit `https://router.huggingface.co/hf-inference/...`, not the `/v1` OpenAI-compat endpoint.

4. **Image generation returns binary**: The HF text-to-image endpoint returns raw image bytes (not base64 JSON like OpenAI/Gemini), so `parse_image_response` would need a custom implementation.

5. **VCR cassettes**: The test suite uses VCR — you'd need to re-record cassettes against the real HF API, or mock them carefully.

---

## Verdict

- **Chat support only**: straightforward, maybe a day's work — it's nearly identical to OpenRouter.
- **Full support (chat + embeddings + images)**: moderate effort, mainly around the models registry and the non-OpenAI-compat endpoints.

---

## Status

- [x] Chat support implemented (`lib/ruby_llm/providers/hugging_face.rb` + `chat.rb`)
- [x] Configuration key added (`hugging_face_api_key`)
- [x] Provider registered (`:hugging_face`)
- [x] Test support wired up (VCR filter, rubyllm config, models_to_test)
- [ ] VCR cassettes recorded (`bundle exec rake vcr:record[hugging_face]`)
- [ ] Embeddings support (`hugging_face/embeddings.rb`)
- [ ] Image generation support (`hugging_face/images.rb`)
