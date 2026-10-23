# MeshStream UniApp Demo

Open this directory as a Vue 3 uni-app project in HBuilderX. Before running, install the parent plugin into this project's `uni_modules/meshstream-p2p` directory through the plugin market or by copying the repository root there.

Run on an Android or iOS custom base first, then cloud package the app. Enter an authorized SDK Key and HTTPS media URL. The default URL matches the Web Demo stream so an Android/Web pair joins the same URL-derived swarm. If the URL differs (for example, signed or local relay URLs), enter the same stable `Content ID` in both clients. The demo refreshes telemetry every two seconds, sends player position and buffer feedback at most once per second, and releases the session/client when playback is stopped or the page is destroyed. Android cloud packages must include the `VideoPlayer` module configured in `manifest.json`.
