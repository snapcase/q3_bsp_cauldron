import Config

# Override with environment variables if present
if baseq3_path = System.get_env("QUAKE3_BASEQ3_PATH") do
  config :q3_bsp_cauldron, baseq3_path: baseq3_path
end

if port = System.get_env("PORT") do
  config :q3_bsp_cauldron, port: String.to_integer(port)
end

# Allow log level to be controlled via environment variable
log_level = System.get_env("LOG_LEVEL", if(config_env() == :prod, do: "info", else: "debug"))
config :logger, level: String.to_atom(log_level)
