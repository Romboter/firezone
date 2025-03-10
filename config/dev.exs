import Config

# Configure your database
if url = System.get_env("DATABASE_URL") do
  config :fz_http, FzHttp.Repo,
    url: url,
    show_sensitive_data_on_connection_error: true,
    pool_size: 10
else
  config :fz_http, FzHttp.Repo,
    username: "postgres",
    password: "postgres",
    database: "firezone_dev",
    ssl: false,
    ssl_opts: [],
    parameters: [],
    hostname: "localhost",
    show_sensitive_data_on_connection_error: true,
    pool_size: 10
end

# For development, we disable any cache and enable
# debugging and code reloading.
config :fz_http, FzHttpWeb.Endpoint,
  http: [port: 13000],
  debug_errors: true,
  code_reloader: true,
  check_origin: ["//127.0.0.1", "//localhost"],
  watchers: [
    node: ["esbuild.js", "dev", cd: Path.expand("../apps/fz_http/assets", __DIR__)]
  ]

get_egress_interface = fn ->
  egress_interface_cmd =
    case :os.type() do
      {:unix, :darwin} -> "netstat -rn -finet | grep '^default' | awk '{print $NF;}'"
      {_os_family, _os_name} -> "route | grep '^default' | grep -o '[^ ]*$'"
    end

  System.cmd("/bin/sh", ["-c", egress_interface_cmd], stderr_to_stdout: true)
  |> elem(0)
  |> String.trim()
end

egress_interface = System.get_env("EGRESS_INTERFACE") || get_egress_interface.()

{fz_wall_cli_module, _} =
  Code.eval_string(System.get_env("FZ_WALL_CLI_MODULE", "FzWall.CLI.Sandbox"))

config :fz_wall,
  nft_path: System.get_env("NFT_PATH", "nft"),
  egress_interface: egress_interface,
  cli: fz_wall_cli_module

{fz_vpn_mod, _} =
  Code.eval_string(System.get_env("FZ_VPN_WG_ADAPTER", "FzVpn.Interface.WGAdapter.Live"))

config :fz_vpn,
  supervised_children: [FzVpn.Interface.WGAdapter.Sandbox, FzVpn.Server, FzVpn.StatsPushService],
  wireguard_private_key_path: "priv/wg_dev_private_key",
  wg_adapter: fz_vpn_mod

# Auth
local_auth_enabled = System.get_env("LOCAL_AUTH_ENABLED") == "true"

config :ueberauth, Ueberauth,
  providers: [
    identity:
      {Ueberauth.Strategy.Identity,
       [
         callback_methods: ["POST"],
         uid_field: :email
       ]}
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Note that this task requires Erlang/OTP 20 or later.
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :fz_http, FzHttpWeb.Endpoint,
  secret_key_base: "5OVYJ83AcoQcPmdKNksuBhJFBhjHD1uUa9mDOHV/6EIdBQ6pXksIhkVeWIzFk5SD",
  live_view: [
    signing_salt: "t01wa0K4lUd7mKa0HAtZdE+jFOPDDejX"
  ],
  live_reload: [
    patterns: [
      ~r"apps/fz_http/priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"apps/fz_http/priv/gettext/.*(po)$",
      ~r"apps/fz_http/lib/fz_http_web/(live|views)/.*(ex)$",
      ~r"apps/fz_http/lib/fz_http_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :fz_http,
  private_clients: ["172.28.0.0/16"],
  cookie_secure: false,
  telemetry_module: FzCommon.MockTelemetry

config :fz_http, FzHttpWeb.Mailer, adapter: Swoosh.Adapters.Local, from_email: "dev@firez.one"
