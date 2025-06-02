import Lenis from 'lenis'

// Initialize Lenis
const lenis = new Lenis({
  autoRaf: true,
  duration: 1.2,
  easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
  orientation: 'vertical',
  gestureOrientation: 'vertical',
  smoothWheel: true,
  syncTouch: false,
  touchMultiplier: 2,
  wheelMultiplier: 1,
  infinite: false,
})

// Listen for the scroll event and refresh AOS
lenis.on('scroll', (e) => {
  // Refresh AOS animations on scroll
  if (typeof AOS !== 'undefined') {
    AOS.refresh();
  }
})

// Make lenis available globally for debugging
window.lenis = lenis; 