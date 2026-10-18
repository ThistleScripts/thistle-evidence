import { useEffect, useRef } from "react";

interface AudioWaveProps {
    active: boolean;
}


export default function AudioWave(props: AudioWaveProps) {
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const animationFrameRef = useRef<number | null>(null);

    useEffect(() => {
        if (!canvasRef.current) return;
        const canvas = canvasRef.current;

        const canvasCtx = canvas.getContext("2d");
        if (!canvasCtx) return;

        const dpr = window.devicePixelRatio || 1;
        const cssW = canvas.clientWidth || canvas.width;
        const cssH = canvas.clientHeight || canvas.height;
        canvas.width = Math.floor(cssW * dpr);
        canvas.height = Math.floor(cssH * dpr);
        canvasCtx.scale(dpr, dpr);

        const width = cssW;
        const height = cssH;
        const centerY = height / 2;

        const step = 8;
        const pointsCount = Math.ceil(width / step) + 2;
        const points = new Array<number>(pointsCount).fill(centerY);
        const targets = new Array<number>(pointsCount).fill(centerY);

        let frameCounter = 0;

        if (!props.active) {
            canvasCtx.clearRect(0, 0, width, height);
            canvasCtx.lineWidth = 2;
            canvasCtx.strokeStyle = "rgb(0, 0, 0)";
            canvasCtx.beginPath();
            canvasCtx.moveTo(0, centerY);
            canvasCtx.lineTo(width, centerY);
            canvasCtx.stroke();

            return;
        }

        const retarget = () => {
            for (let i = 0; i < pointsCount; i++) {
                const edgeFalloff = 1 - Math.abs((i / (pointsCount - 1)) * 2 - 1);
                const jitter = (Math.random() * 2 - 1) * (height * 0.45) * (0.6 + 0.4 * edgeFalloff);
                targets[i] = centerY + jitter;
            }
        };

        const drawSmooth = () => {
            frameCounter++;

            if (frameCounter % 6 === 0) {
                retarget();
            }

            for (let i = 0; i < pointsCount; i++) {
                points[i]! += (targets[i]! - points[i]!) * 0.15;
            }

            canvasCtx.clearRect(0, 0, width, height);

            canvasCtx.lineWidth = 2;
            canvasCtx.lineJoin = "round";
            canvasCtx.lineCap = "round";
            canvasCtx.strokeStyle = "rgb(0, 0, 0)";

            canvasCtx.beginPath();

            let x0 = 0;
            let y0 = points[0];
            canvasCtx.moveTo(x0, y0);

            for (let i = 1; i < pointsCount; i++) {
                const x = i * step;
                const y = points[i];

                const xc = (x0 + x) / 2;
                const yc = (y0 + y) / 2;

                canvasCtx.quadraticCurveTo(x0, y0, xc, yc);

                x0 = x;
                y0 = y;
            }

            canvasCtx.quadraticCurveTo(x0, y0, width, points[pointsCount - 1]);
            canvasCtx.stroke();

            animationFrameRef.current = requestAnimationFrame(drawSmooth);
        };

        retarget();
        animationFrameRef.current = requestAnimationFrame(drawSmooth);

        return () => {
            if (animationFrameRef.current) {
                cancelAnimationFrame(animationFrameRef.current);
                animationFrameRef.current = null;
            }
        }
    }, [props.active]);

    return <canvas ref={canvasRef} className="w-full h-6"></canvas>;
}