# CLAUDE.md

## Skills-CLI in Cloud-Sessions

In Claude-Code-Cloud-Sessions geht ausgehendes HTTPS über einen Agent-Proxy. Node nutzt ihn nicht von selbst, und `npx skills find` meldet dann ohne Fehlermeldung „No skills found“. Jeden Aufruf des Skills-CLI (`find`, `add`, `update`) mit diesen Variablen ausführen:

```bash
NODE_USE_ENV_PROXY=1 NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt npx skills find <query>
```

- `skills.sh` (Such-API) muss in der Umgebung unter Allowed domains freigegeben sein.
- Installationen laufen durch den SkillSpector-Gate (`.claude/hooks/skillspector-gate.py`). Geprüfte Befunde werden in `.claude/hooks/skillspector-allow.json` eingetragen, nicht am Gate vorbei installiert.
- Skills, die bleiben sollen, ohne `-g` ins Repo installieren (`.claude/skills/`) und committen. Mit `-g` installierte Skills gehen am Ende der Session verloren.
