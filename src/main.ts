import Phaser from "phaser";
import { RoomScene } from "./scenes/RoomScene";
import "./style.css";

function requireElement<T extends HTMLElement>(id: string): T {
  const element = document.getElementById(id);
  if (!element) throw new Error(`Missing page element: ${id}`);
  return element as T;
}

const host = requireElement<HTMLDivElement>("game");
const wakeButton = requireElement<HTMLButtonElement>("wake-room");
const environmentStatus = requireElement<HTMLParagraphElement>("environment-status");
const interactionStatus = requireElement<HTMLSpanElement>("interaction-status");
let interactions = 0;
const replies = ["它晃了晃叶子，像是在说你好", "听见了，小家伙又靠近了一点", "房间里多了一点热闹的声音"];

const scene = new RoomScene({
  onReady: () => {
    host.dataset.gameReady = "true";
    environmentStatus.textContent = "环境已就绪";
    wakeButton.disabled = false;
  },
  onInteraction: () => {
    interactions += 1;
    host.dataset.interactionCount = String(interactions);
    interactionStatus.textContent = replies[(interactions - 1) % replies.length] ?? replies[0] ?? "房间回应了你";
  },
});

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: host,
  width: 400,
  height: 500,
  backgroundColor: "#faf8f0",
  scene: [scene],
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  render: { antialias: true, roundPixels: false },
  input: { activePointers: 2 },
  audio: { noAudio: true },
});

const wakeRoom = (): void => scene.wake();
wakeButton.addEventListener("click", wakeRoom);

if (import.meta.hot) {
  import.meta.hot.dispose(() => {
    wakeButton.removeEventListener("click", wakeRoom);
    host.dataset.gameReady = "false";
    wakeButton.disabled = true;
    game.destroy(true);
  });
}
