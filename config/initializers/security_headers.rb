Rails.application.configure do
  config.action_dispatch.default_headers["X-Content-Type-Options"] = "nosniff"

  config.public_file_server.headers = (config.public_file_server.headers || {}).merge(
    "X-Content-Type-Options" => "nosniff"
  )
end
