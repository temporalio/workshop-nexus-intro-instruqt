// Slidev setup hook: auto-tag "Build N -" markers in speaker notes so CSS can color them.
// Runs in the browser; matches <strong> whose text starts with "Build <digits>" and adds .note-build-marker.

export default function () {
  if (typeof window === 'undefined') return

  const tag = (root: ParentNode) => {
    root.querySelectorAll('strong:not(.note-build-marker)').forEach((el) => {
      if (/^Build \d+/.test(el.textContent ?? '')) el.classList.add('note-build-marker')
    })
  }

  const start = () => {
    tag(document.body)
    new MutationObserver((muts) => {
      for (const m of muts) {
        m.addedNodes.forEach((n) => {
          if (n.nodeType === 1) tag(n as Element)
        })
      }
    }).observe(document.body, { subtree: true, childList: true })
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true })
  } else {
    start()
  }
}
