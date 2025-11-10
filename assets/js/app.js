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
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/bloc_the_line"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Local client-side hooks. MovingBlock implements a frontend-only movable overlay
// that snaps to the tile grid and is controllable with WASD.
const localHooks = {
  MovingBlock: {
    mounted() {
      const container = this.el

      // read grid size from data attributes (set server-side in the component)
      const rows = parseInt(container.dataset.rows, 10) || 0
      const cols = parseInt(container.dataset.cols, 10) || 0

      const blockEl = container.querySelector('.moving-block')
      const tileEl = container.querySelector('.blokus-tile')
      if (!blockEl || !tileEl) return

      // Support all valid polyomino shapes (1 to 5 tiles)
      const SHAPES = [
        // size 1
        {name: '1', cells: [[0,0]]},
        // size 2
        {name: '2', cells: [[0,0],[1,0]]},
        // size 3
        {name: 'I3', cells: [[0,0],[1,0],[2,0]]},
        {name: 'V3', cells: [[0,0],[0,1],[1,1]]},
        // size 4
        {name: 'I4', cells: [[0,0],[1,0],[2,0],[3,0]]},
        {name: 'O', cells: [[0,0],[1,0],[0,1],[1,1]]},
        {name: 'T4', cells: [[0,0],[1,0],[2,0],[1,1]]},
        {name: 'L4', cells: [[0,0],[0,1],[0,2],[1,0]]},
        {name: 'Z4', cells: [[0,0],[1,0],[1,1],[2,1]]},
        // size 5
        {name: 'F', cells: [[1,0],[0,1],[1,1],[1,2],[2,2]]},
        {name: 'I5', cells: [[0,0],[1,0],[2,0],[3,0],[4,0]]},
        {name: 'L5', cells: [[0,0],[0,1],[0,2],[0,3],[1,0]]},
        {name: 'Z5', cells: [[0,0],[1,0],[1,1],[1,2],[2,2]]},
        {name: 'P', cells: [[0,0],[1,0],[0,1],[1,1],[0,2]]},
        {name: 'T5', cells: [[0,0],[1,0],[2,0],[1,1],[1,2]]},
        {name: 'U', cells: [[0,0],[0,1],[1,0],[2,0],[2,1]]},
        {name: 'V5', cells: [[0,0],[0,1],[0,2],[1,0],[2,0]]},
        {name: 'W', cells: [[0,0],[1,0],[1,1],[2,1],[2,2]]},
        {name: 'X', cells: [[1,0],[0,1],[1,1],[2,1],[1,2]]},
        {name: 'Y', cells: [[0,0],[1,0],[2,0],[3,0],[2,1]]}
      ]

      let shapeIndex = 0
      // current oriented cells (normalized to min 0,0)
      let oriented = normalize(SHAPES[shapeIndex].cells)

      // position in tile coords (this is the top-left origin we place the shape at)
      let row = parseInt(blockEl.dataset.row, 10) || 0
      let col = parseInt(blockEl.dataset.col, 10) || 0

      let tileW = 0
      let tileH = 0

      function normalize(cells) {
        const xs = cells.map(c => c[0])
        const ys = cells.map(c => c[1])
        const minx = Math.min(...xs)
        const miny = Math.min(...ys)
        return cells.map(c => [c[0]-minx, c[1]-miny])
      }

      function rotate90(cells) {
        const rotated = cells.map(([x,y]) => [-y, x])
        return normalize(rotated)
      }

      function flipX(cells) {
        const flipped = cells.map(([x,y]) => [-x, y])
        return normalize(flipped)
      }

      function bounds(cells) {
        const xs = cells.map(c => c[0])
        const ys = cells.map(c => c[1])
        return {maxX: Math.max(...xs), maxY: Math.max(...ys)}
      }

      const renderShape = () => {
        // compute measurements first
        if (!tileW || !tileH) return
        const b = bounds(oriented)
        const shapeW = b.maxX + 1
        const shapeH = b.maxY + 1

        // clamp to board
        row = Math.max(0, Math.min(row, Math.max(0, rows - shapeH)))
        col = Math.max(0, Math.min(col, Math.max(0, cols - shapeW)))

        blockEl.style.position = 'absolute'
        blockEl.style.left = '0'
        blockEl.style.top = '0'
        blockEl.style.width = (shapeW * tileW) + 'px'
        blockEl.style.height = (shapeH * tileH) + 'px'
        blockEl.style.transform = `translate(${col * tileW}px, ${row * tileH}px)`
        blockEl.style.transition = 'transform 0.04s linear'

        // render tiles inside blockEl
        blockEl.innerHTML = ''
        oriented.forEach(([x,y]) => {
          const t = document.createElement('div')
          t.className = 'moving-block-tile'
          t.style.position = 'absolute'
          t.style.left = (x * tileW) + 'px'
          t.style.top = (y * tileH) + 'px'
          t.style.width = tileW + 'px'
          t.style.height = tileH + 'px'
          blockEl.appendChild(t)
        })
        blockEl.dataset.shape = SHAPES[shapeIndex].name
      }

      const measure = () => {
        const r = tileEl.getBoundingClientRect()
        tileW = Math.round(r.width)
        tileH = Math.round(r.height)
        renderShape()
      }

      // keyboard handling: WASD or arrow keys, plus shape controls
      const keyHandler = (e) => {
        const key = (e.key || '').toLowerCase()
        let moved = false

        if (key === 'w' || key === 'arrowup') { row -= 1; moved = true }
        else if (key === 's' || key === 'arrowdown') { row += 1; moved = true }
        else if (key === 'a' || key === 'arrowleft') { col -= 1; moved = true }
        else if (key === 'd' || key === 'arrowright') { col += 1; moved = true }
        else if (key === 'r' || key === 'f' || key === ']' || key === '[') {
          // preserve top-left anchor of the shape's bounding box so rotations
          // and shape switches feel stable
          const anchorRow = row
          const anchorCol = col

          if (key === 'r') {
            oriented = rotate90(oriented)
          } else if (key === 'f') {
            oriented = flipX(oriented)
          } else if (key === ']') { // next shape
            shapeIndex = (shapeIndex + 1) % SHAPES.length
            oriented = normalize(SHAPES[shapeIndex].cells)
          } else if (key === '[') { // prev shape
            shapeIndex = (shapeIndex - 1 + SHAPES.length) % SHAPES.length
            oriented = normalize(SHAPES[shapeIndex].cells)
          }

          // for top-left anchoring we keep the same (row, col) origin
          row = anchorRow
          col = anchorCol

          e.preventDefault()
          renderShape()
        }

        if (moved) {
          e.preventDefault()
          renderShape()
        }
      }

      // handle resize so snapping remains correct
      const ro = new ResizeObserver(() => {
        measure()
      })
      ro.observe(tileEl)

      // measure initially after layout
      requestAnimationFrame(measure)

      window.addEventListener('keydown', keyHandler)

      this.destroy = () => {
        window.removeEventListener('keydown', keyHandler)
        try { ro.disconnect() } catch (e) {}
      }
    },
    destroyed() {
      if (this.destroy) this.destroy()
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...localHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

