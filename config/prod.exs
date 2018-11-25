use Mix.Config

config :skn_bot,
  namespace: Skn,
  ecto_repos: [Skn.Bot.Repo]

config :skn_bot,
  Skn.Bot.Repo,
  username: "postgres",
  password: "abc@123",
  database: "ea18_dev",
  hostname: "127.0.0.1",
  pool_size: 2
