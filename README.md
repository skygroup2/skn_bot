# skn_bot

***API for bot database ***

### Dev

```text
    configuration
    bot_keep_uuid : true/false  (keep or delete uuid data when Skn.Bot.delete)
    
```

### Migration 

```bash
    mix ecto.migrate -r Skn.Bot.Repo --log-sql
    mix ecto.rollback -r Skn.Bot.Repo --log-sql
    
    mix ecto.rollback -r Skn.Bot.Repo --log-sql --to 20181125012555
```