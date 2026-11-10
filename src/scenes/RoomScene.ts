import Phaser from "phaser";

type RoomCallbacks = {
  onReady: () => void;
  onInteraction: () => void;
};

const COLORS = {
  canvas: 0xfaf8f0,
  wall: 0xecebdc,
  edge: 0xd9deca,
  floor: 0xe4ddc8,
  green: 0x8ca77d,
  dark: 0x49654d,
};

export class RoomScene extends Phaser.Scene {
  private readonly callbacks: RoomCallbacks;
  private readonly reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  private pet?: Phaser.GameObjects.Container;
  private eyes?: Phaser.GameObjects.Container;
  private blinkTimer?: Phaser.Time.TimerEvent;
  private lastInteraction = -Infinity;
  private cleaned = false;

  constructor(callbacks: RoomCallbacks) {
    super({ key: "RoomScene" });
    this.callbacks = callbacks;
  }

  create(): void {
    this.cleaned = false;
    this.cameras.main.setBackgroundColor(COLORS.canvas);
    this.drawRoom();
    this.drawPet();
    this.input.on(Phaser.Input.Events.POINTER_DOWN, this.wake, this);
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, this.cleanup, this);
    this.events.once(Phaser.Scenes.Events.DESTROY, this.cleanup, this);
    this.callbacks.onReady();
  }

  wake(): void {
    if (!this.pet || this.cleaned || this.time.now - this.lastInteraction < 230) return;
    this.lastInteraction = this.time.now;
    this.callbacks.onInteraction();
    this.tweens.killTweensOf(this.pet);
    this.pet.setScale(1);
    this.tweens.add({
      targets: this.pet,
      scaleX: 1.08,
      scaleY: 0.93,
      duration: this.reducedMotion ? 0 : 130,
      yoyo: true,
      ease: "Sine.easeInOut",
    });

    const ring = this.add.ellipse(202, 358, 137, 49).setStrokeStyle(2, 0x9fb28d, 0.7);
    this.tweens.add({ targets: ring, scale: 1.6, alpha: 0, duration: this.reducedMotion ? 120 : 750, onComplete: () => ring.destroy() });

    if (!this.reducedMotion) {
      for (let i = 0; i < 6; i += 1) {
        const angle = Math.PI + (i / 5) * Math.PI;
        const sparkle = this.add.star(202 + Math.cos(angle) * 38, 307 + Math.sin(angle) * 30, 4, 2, 6, i % 2 === 0 ? 0xc8b772 : 0x9db28a);
        this.tweens.add({
          targets: sparkle,
          x: 202 + Math.cos(angle) * 82,
          y: 289 + Math.sin(angle) * 68,
          alpha: 0,
          scale: 0.5,
          duration: 700,
          ease: "Cubic.easeOut",
          onComplete: () => sparkle.destroy(),
        });
      }
    }
  }

  private drawRoom(): void {
    const g = this.add.graphics();
    g.fillStyle(0xe5e5d7, 0.4);
    g.fillEllipse(200, 427, 314, 31);
    g.fillStyle(COLORS.edge);
    g.fillRoundedRect(30, 63, 340, 365, 36);
    g.fillStyle(COLORS.wall);
    g.fillRoundedRect(36, 67, 328, 350, 31);
    g.fillStyle(COLORS.floor);
    g.fillRoundedRect(36, 268, 328, 149, { tl: 7, tr: 7, bl: 31, br: 31 });
    g.lineStyle(1, 0xd0c9b5, 0.65);
    g.lineBetween(37, 312, 363, 312);
    g.lineBetween(42, 362, 358, 362);
    g.lineBetween(106, 268, 86, 411);
    g.lineBetween(202, 268, 202, 416);
    g.lineBetween(298, 268, 318, 411);

    // A little recessed window and a patch of afternoon light.
    g.fillStyle(0xd7ddc6);
    g.fillRoundedRect(129, 107, 110, 133, 37);
    g.fillStyle(0xf6f4dc);
    g.fillRoundedRect(137, 114, 94, 117, 31);
    g.fillStyle(0xdde3c4);
    g.fillEllipse(186, 213, 89, 32);
    g.fillStyle(0xd2dac0);
    g.fillRect(181, 116, 6, 115);
    g.fillRect(139, 173, 90, 6);
    g.fillStyle(0xc8d0b4);
    g.fillRoundedRect(122, 232, 125, 9, 4);
    g.fillStyle(0xfcf7db, 0.55);
    g.fillPoints([
      new Phaser.Math.Vector2(141, 273), new Phaser.Math.Vector2(227, 273),
      new Phaser.Math.Vector2(296, 364), new Phaser.Math.Vector2(164, 364),
    ], true);

    // A shelf, a tiny picture, and a well-loved cabinet.
    g.fillStyle(0xcbd4bb);
    g.fillRoundedRect(274, 131, 45, 50, 5);
    g.fillStyle(0xf4f1df);
    g.fillRoundedRect(279, 136, 35, 40, 3);
    g.fillStyle(0xa4b693);
    g.fillCircle(296, 154, 8);
    g.fillStyle(0xd4ccb2);
    g.fillRoundedRect(269, 233, 63, 64, 9);
    g.fillStyle(0xe0d7bd);
    g.fillRoundedRect(266, 228, 69, 12, 5);
    g.lineStyle(1, 0xb9b59d, 0.65);
    g.lineBetween(277, 261, 324, 261);
    g.fillStyle(0xa2aa8c);
    g.fillCircle(300, 250, 2.5);
    g.fillCircle(300, 277, 2.5);
    g.fillStyle(0xf4eed5);
    g.fillRoundedRect(285, 209, 21, 18, 4);
    g.lineStyle(3, 0xc8c9aa);
    g.strokeCircle(308, 216, 5);

    // The room's plant uses only simple shapes, keeping this scaffold asset-free.
    g.fillStyle(0xcfc7ae);
    g.fillRoundedRect(70, 251, 41, 40, { tl: 3, tr: 3, bl: 13, br: 13 });
    g.fillStyle(0xe2d8bf);
    g.fillRoundedRect(66, 247, 49, 10, 4);
    g.lineStyle(3, 0x91a17c);
    g.lineBetween(90, 248, 90, 208);
    this.add.ellipse(79, 223, 26, 12, 0x9eaf8c).setAngle(32);
    this.add.ellipse(101, 211, 27, 13, 0x8da17a).setAngle(-32);
    this.add.ellipse(86, 202, 22, 12, 0xb0bd9b).setAngle(55);

    this.add.ellipse(202, 355, 198, 84, 0xcbd2b6);
    this.add.ellipse(202, 355, 180, 68).setStrokeStyle(1, 0xe6e8d0, 0.8);
    this.add.ellipse(202, 362, 100, 25, 0xa8b28f, 0.45);

    this.add.text(200, 462, "这里有一点点生命的迹象。", {
      fontFamily: '-apple-system, "PingFang SC", sans-serif',
      fontSize: "11px",
      color: "#a0a88f",
      letterSpacing: 1,
    }).setOrigin(0.5);
  }

  private drawPet(): void {
    const pet = this.add.container(202, 325);
    pet.add(this.add.ellipse(-25, 26, 25, 14, 0x7f9971));
    pet.add(this.add.ellipse(25, 26, 25, 14, 0x7f9971));
    pet.add(this.add.ellipse(0, -3, 90, 73, COLORS.green));
    pet.add(this.add.ellipse(-18, -31, 23, 31, 0x8ca77d).setAngle(-25));
    pet.add(this.add.ellipse(20, -31, 23, 31, 0x8ca77d).setAngle(25));
    pet.add(this.add.ellipse(0, 8, 61, 42, 0xa5bc91));
    pet.add(this.add.ellipse(-23, 10, 12, 6, 0xc1c09a, 0.75));
    pet.add(this.add.ellipse(23, 10, 12, 6, 0xc1c09a, 0.75));
    const eyes = this.add.container(0, 0);
    eyes.add(this.add.ellipse(-14, 0, 5, 8, COLORS.dark));
    eyes.add(this.add.ellipse(14, 0, 5, 8, COLORS.dark));
    pet.add(eyes);
    const mouth = this.add.graphics();
    mouth.lineStyle(1.8, COLORS.dark);
    mouth.beginPath();
    mouth.arc(0, 10, 4, 0.1, Math.PI - 0.1);
    mouth.strokePath();
    pet.add(mouth);
    const leaf = this.add.ellipse(3, -49, 24, 10, 0xb0bf95).setAngle(-35);
    pet.add(leaf);
    this.pet = pet;
    this.eyes = eyes;

    if (!this.reducedMotion) {
      this.tweens.add({ targets: leaf, angle: -23, duration: 1900, yoyo: true, repeat: -1, ease: "Sine.easeInOut" });
      this.blinkTimer = this.time.addEvent({
        delay: 3700,
        loop: true,
        callback: () => {
          if (this.eyes) this.tweens.add({ targets: this.eyes, scaleY: 0.15, duration: 100, yoyo: true });
        },
      });
    }
  }

  private cleanup(): void {
    if (this.cleaned) return;
    this.cleaned = true;
    this.input.off(Phaser.Input.Events.POINTER_DOWN, this.wake, this);
    this.blinkTimer?.remove(false);
    this.blinkTimer = undefined;
    this.tweens.killAll();
    this.pet = undefined;
    this.eyes = undefined;
  }
}
