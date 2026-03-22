export function HeroMeshGradient({ className = "", fixed = false }) {
  return (
    <div
      className={`pointer-events-none ${fixed ? 'fixed inset-0 z-0' : 'absolute inset-0'} ${className}`}
      aria-hidden="true"
      style={{ opacity: 0.45 }}
    >
      <div
        className="mesh-gradient"
        style={{ width: "100%", height: "100%" }}
      />
    </div>
  );
}
