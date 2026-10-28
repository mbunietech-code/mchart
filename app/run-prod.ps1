Set-Location $PSScriptRoot
# Realtime over soketi on the VPS (wss://ws.mbunie.tech); the key is the public Pusher app key.
flutter run -d 060763713F108953 --dart-define=MCHART_API=https://chart.mbunie.tech --dart-define=MCHART_REVERB_HOST=ws.mbunie.tech --dart-define=MCHART_REVERB_PORT=443 --dart-define=MCHART_REVERB_SCHEME=wss --dart-define=MCHART_REVERB_KEY=03120d5a258eafdde73d09ffbdeb515d1c2d58d8
