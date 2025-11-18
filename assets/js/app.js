// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/bloc_the_line";
import topbar from "../vendor/topbar";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

// Local client-side hooks. MovingBlock implements a frontend-only movable overlay
// that snaps to the tile grid and is controllable with WASD.
const localHooks = {
  MovingBlock: {
    mounted() {
      const container = this.el;

      // read grid size from data attributes
      const rows = parseInt(container.dataset.rows, 10) || 0;
      const cols = parseInt(container.dataset.cols, 10) || 0;

      const blockEl = container.querySelector(".moving-block");
      const tileEl = container.querySelector(".blokus-tile");
      if (!blockEl || !tileEl) return;

      const SHAPES = JSON.parse(container.dataset.pieces);

      let shapeIndex = 0;
      // current oriented cells - keep relative to anchor at [0,0]
      let oriented = SHAPES[shapeIndex].cells;

      // anchor's row/col pos in tile coords
      let anchorRow = parseInt(blockEl.dataset.row, 10) || 2;
      let anchorCol = parseInt(blockEl.dataset.col, 10) || 2;

      let tileW = 0;
      let tileH = 0;
      // When true, all keyboard input for piece movement/rotation is ignored.
      let inputBlocked = false;

      function normalize(cells) {
        const xs = cells.map((c) => c[0]);
        const ys = cells.map((c) => c[1]);
        const minx = Math.min(...xs);
        const miny = Math.min(...ys);
        return cells.map((c) => [c[0] - minx, c[1] - miny]);
      }

      function bounds(cells) {
        const xs = cells.map((c) => c[0]);
        const ys = cells.map((c) => c[1]);
        return {
          minX: Math.min(...xs),
          maxX: Math.max(...xs),
          minY: Math.min(...ys),
          maxY: Math.max(...ys),
        };
      }

      // force the piece to stay inside the board boundaries
      function clampAnchorToBoard(
        anchorRow,
        anchorCol,
        bounds,
        anchor,
        rows,
        cols
      ) {
        const [anchorX, anchorY] = anchor;

        // find each cell boundary on the board
        const minBoardRow = anchorRow + (bounds.minY - anchorY);
        const maxBoardRow = anchorRow + (bounds.maxY - anchorY);
        const minBoardCol = anchorCol + (bounds.minX - anchorX);
        const maxBoardCol = anchorCol + (bounds.maxX - anchorX);

        // clamp all positions to the board
        if (minBoardRow < 0) anchorRow -= minBoardRow;
        if (minBoardCol < 0) anchorCol -= minBoardCol;
        if (maxBoardRow >= rows) anchorRow -= maxBoardRow - rows + 1;
        if (maxBoardCol >= cols) anchorCol -= maxBoardCol - cols + 1;

        return { anchorRow, anchorCol };
      }

      const renderShape = (enableTransition = false) => {
        // compute measurements first
        if (!tileW || !tileH) return;
        const b = bounds(oriented);
        const anchor = SHAPES[shapeIndex].anchor;

        // convert anchor to x, y
        const [anchorX, anchorY] = anchor;

        // calculate the bounding box size
        const shapeW = b.maxX - b.minX + 1;
        const shapeH = b.maxY - b.minY + 1;

        // clamp anchor to keep piece on board
        const clamped = clampAnchorToBoard(
          anchorRow,
          anchorCol,
          b,
          anchor,
          rows,
          cols
        );
        anchorRow = clamped.anchorRow;
        anchorCol = clamped.anchorCol;

        // get anchor board position
        const anchorCellRow = anchorRow;
        const anchorCellCol = anchorCol;

        // convert anchor to pixel position
        const anchorPixelX = anchorCellCol * tileW;
        const anchorPixelY = anchorCellRow * tileH;

        const boxPixelX = anchorPixelX - (anchorX - b.minX) * tileW;
        const boxPixelY = anchorPixelY - (anchorY - b.minY) * tileH;

        blockEl.style.position = "absolute";
        blockEl.style.left = "0";
        blockEl.style.top = "0";
        blockEl.style.width = shapeW * tileW + "px";
        blockEl.style.height = shapeH * tileH + "px";
        blockEl.style.transform = `translate(${boxPixelX}px, ${boxPixelY}px)`;

        // enable transition for movement, but not rotation
        blockEl.style.transition = enableTransition
          ? "transform 0.15s ease-out"
          : "none";

        // render tiles...
        blockEl.innerHTML = "";
        oriented.forEach(([x, y]) => {
          const t = document.createElement("div");
          t.className = "moving-block-tile";
          t.style.position = "absolute";
          t.style.left = (x - b.minX) * tileW + "px";
          t.style.top = (y - b.minY) * tileH + "px";
          t.style.width = tileW + "px";
          t.style.height = tileH + "px";
          blockEl.appendChild(t);

          if (x === anchorX && y === anchorY) {
            const dot = document.createElement("div");
            dot.className = "anchor-dot";
            dot.style.position = "absolute";
            dot.style.width = "8px";
            dot.style.height = "8px";
            dot.style.borderRadius = "50%";
            dot.style.backgroundColor = "yellow";
            dot.style.top = "50%";
            dot.style.left = "50%";
            dot.style.transform = "translate(-50%, -50%)";
            dot.style.zIndex = "10";
            t.appendChild(dot);
          }
        });

        blockEl.dataset.shape = SHAPES[shapeIndex].name;
      };

      const measure = () => {
        const r = tileEl.getBoundingClientRect();
        tileW = Math.round(r.width);
        tileH = Math.round(r.height);
        renderShape();
      };

      // keyboard handling: WASD or arrow keys, plus shape controls
      const keyHandler = (e) => {
        if (inputBlocked) {
          e.preventDefault();
          return;
        }
        const key = (e.key || "").toLowerCase();
        let moved = false;

        if (key === "w" || key === "arrowup") {
          anchorRow -= 1;
          moved = true;
        } else if (key === "s" || key === "arrowdown") {
          anchorRow += 1;
          moved = true;
        } else if (key === "a" || key === "arrowleft") {
          anchorCol -= 1;
          moved = true;
        } else if (key === "d" || key === "arrowright") {
          anchorCol += 1;
          moved = true;
        } else if (key === "r") {
          // rotate clockwise
          e.preventDefault();
          this.pushEvent(
            "rotate_piece",
            {
              cells: oriented,
              corners: SHAPES[shapeIndex].corners || [],
              anchor: SHAPES[shapeIndex].anchor,
              direction: "cw",
            },
            (reply) => {
              oriented = reply.cells;
              SHAPES[shapeIndex].corners = reply.corners;
              SHAPES[shapeIndex].anchor = reply.anchor;
              renderShape(false); // false = no transition
            }
          );
          return;
        } else if (key === "e") {
          // rotate counter-clockwise
          e.preventDefault();
          this.pushEvent(
            "rotate_piece",
            {
              cells: oriented,
              corners: SHAPES[shapeIndex].corners || [],
              anchor: SHAPES[shapeIndex].anchor,
              direction: "ccw",
            },
            (reply) => {
              oriented = reply.cells;
              SHAPES[shapeIndex].corners = reply.corners;
              SHAPES[shapeIndex].anchor = reply.anchor;
              renderShape(false); // false = no transition
            }
          );
          return;
        } else if (key === "f") {
          // flip horizontal
          e.preventDefault();
          blockEl.style.transition = "none";
          this.pushEvent(
            "flip_piece",
            {
              cells: oriented,
              corners: SHAPES[shapeIndex].corners || [],
              anchor: SHAPES[shapeIndex].anchor,
              axis: "horizontal",
            },
            (reply) => {
              oriented = reply.cells;
              SHAPES[shapeIndex].corners = reply.corners;
              SHAPES[shapeIndex].anchor = reply.anchor;
              renderShape();
            }
          );
          return;
        } else if (key === "v") {
          // flip vertical
          e.preventDefault();
          blockEl.style.transition = "none";
          this.pushEvent(
            "flip_piece",
            {
              cells: oriented,
              corners: SHAPES[shapeIndex].corners || [],
              anchor: SHAPES[shapeIndex].anchor,
              axis: "vertical",
            },
            (reply) => {
              oriented = reply.cells;
              SHAPES[shapeIndex].corners = reply.corners;
              SHAPES[shapeIndex].anchor = reply.anchor;
              renderShape();
            }
          );
          return;
        } else if (key === "]") {
          // next shape
          shapeIndex = (shapeIndex + 1) % SHAPES.length;
          oriented = SHAPES[shapeIndex].cells;

          console.log(
            "Switched to:",
            SHAPES[shapeIndex].name,
            "Anchor:",
            SHAPES[shapeIndex].anchor
          );
        } else if (key === "[") {
          // prev shape
          shapeIndex = (shapeIndex - 1 + SHAPES.length) % SHAPES.length;
          oriented = SHAPES[shapeIndex].cells;

          console.log(
            "Switched to:",
            SHAPES[shapeIndex].name,
            "Anchor:",
            SHAPES[shapeIndex].anchor
          );
        } else if (key === " ") {
          // spacebar - attempt to place piece
          e.preventDefault();
          // Failure - piece cannot be placed
          console.log("Cannot place piece here!");

          // Hide the live moving block and create a temporary animated clone child
          // the child will be animated to indicate error, then removed
          // don't animate the live element directly as it will mess up positioning with translate
          blockEl.style.visibility = "hidden";
          blockEl.style.pointerEvents = "none";

          const clone = blockEl.cloneNode(true);
          blockEl.appendChild(clone);
          clone.classList.add("piece-placed-error");
          clone.style.visibility = "visible";
          clone.style.position = "absolute";
          clone.style.transform = "translate(0, 0)";

          // Block input while the shake/flash animation runs
          inputBlocked = true;

          // Remove clone and restore original after the animation ends.
          setTimeout(() => {
            try { clone.remove(); } catch (e) {}
            blockEl.style.visibility = "visible";
            blockEl.style.pointerEvents = "";
            // Restore input after animation finishes
            inputBlocked = false;
          }, 500);

          return;
        }

        if (moved || ["]", "["].includes(key)) {
          e.preventDefault();
          renderShape(moved); // sets transition only if moved
        }
      };

      // handle resize so snapping remains correct
      const ro = new ResizeObserver(() => {
        measure();
      });
      ro.observe(tileEl);

      // measure initially after layout
      requestAnimationFrame(measure);

      window.addEventListener("keydown", keyHandler);

      this.destroy = () => {
        window.removeEventListener("keydown", keyHandler);
        try {
          ro.disconnect();
        } catch (e) {}
      };
    },
    destroyed() {
      if (this.destroy) this.destroy()
    }
  },

  Timer: {
    mounted() {
      let timeRemaining = parseInt(this.el.dataset.seconds, 10)
      const timerEl = this.el.querySelector('.timer-display')

      timerEl.innerHTML = ''
      const countdown = setInterval(() => {
        timerEl.textContent = `Time Remaining: ${timeRemaining--}s`

        if (timeRemaining < 0) {
          clearInterval(countdown)
          timerEl.textContent = `Time's up!`
        }

      }, 1000)

      // Avoid memory leaks
      this.destroy = () => {
        clearInterval(countdown)
      }
    },

    destroyed() {
      if (this.destroy) this.destroy()
    }
  },

  CopyToClipboard: {
    mounted() {
      this.el.addEventListener("click", e => {
        const text = this.el.dataset.text
        navigator.clipboard.writeText(text).then(() => {
          setTimeout(() => {
            this.pushEvent("reset_copied", {})
          }, 2000)
        })
      })
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...colocatedHooks, ...localHooks },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true
      );

      window.liveReloader = reloader;
    }
  );
}
