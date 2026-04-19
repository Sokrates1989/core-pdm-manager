# AI Conflict Guidance Workflow

The AI guidance workflow is optional and user-controlled.

## 1) What is produced

After running sanity checks, the tool can generate:

- `./.pdm-manager/reports/dependency-sanity-report.json`
- `./.pdm-manager/reports/ai-solve-guidance.md`
- `./.pdm-manager/reports/ai-solve-prompt.txt`

## 2) Recommended flow

1. Run sanity check:
   - Bash: `./scripts/sanity-check.sh --project-root . --include-dev`
   - PowerShell: `.\scripts\sanity-check.ps1 -ProjectRoot . -IncludeDev`
2. If failures exist, generate guidance:
   - Bash: `./scripts/ai-solve-guidance.sh --project-root . --print-prompt`
   - PowerShell: `.\scripts\ai-solve-guidance.ps1 -ProjectRoot . -PrintPrompt`
3. Optionally paste prompt into your preferred AI assistant.
4. Apply suggested fixes manually.
5. Re-run sanity check.

## 2.1) Optional external AI invocation (explicit opt-in)

You can let the tool call an OpenAI-compatible endpoint directly.

### Bash

```bash
./scripts/ai-solve-guidance.sh \
  --project-root . \
  --use-external-ai \
  --provider-endpoint "https://api.openai.com/v1/chat/completions" \
  --provider-model "gpt-4o-mini" \
  --provider-api-key-env OPENAI_API_KEY
```

### PowerShell

```powershell
.\scripts\ai-solve-guidance.ps1 `
  -ProjectRoot . `
  -UseExternalAi `
  -ProviderEndpoint "https://api.openai.com/v1/chat/completions" `
  -ProviderModel "gpt-4o-mini" `
  -ProviderApiKeyEnv "OPENAI_API_KEY"
```

Generated provider output file:

- `./.pdm-manager/reports/ai-provider-response.txt`

## 3) Privacy and safety

- No secrets are read from host `.env` for prompt construction.
- Generated prompts are based on dependency and import errors only.
- Keep manual approval before applying lockfile/package modifications.
- External provider mode is disabled by default and must be explicitly enabled.
- API keys are loaded from environment variables only (never hardcoded).

## 4) Typical resolution loop

```bash
pdm show --graph
pdm lock --refresh
pdm sync --clean
python -m pip check
```

Then run sanity check again.
