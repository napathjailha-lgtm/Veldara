# Play Veldara in a browser

The GitHub Actions workflow exports this Godot project to HTML5/WebAssembly and publishes the exported build to GitHub Pages from the `feature/godot-25d-rebuild` branch.

## First-time setup
1. In the repository, open **Settings → Pages**.
2. Under **Build and deployment**, select **GitHub Actions** as the source.
3. Open **Actions** and run **Build and deploy Veldara Web** using **Run workflow**, or push a change under `godot/` on `feature/godot-25d-rebuild`.
4. Wait for both the build and deploy jobs to pass. The workflow's deployment environment displays the published URL.

## Controls
- WASD / arrow keys: move
- E: catch a nearby wild monster
- T: train and gain EXP
- V: evolve when eligible

The browser build is generated from the Godot project. It is not a separate HTML mockup. A successful export and Pages deployment are required before the game URL is live.
