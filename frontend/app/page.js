"use client"
import styles from "./page.module.css";
import { useState, useEffect, useRef } from "react";
import '@aws-amplify/ui-react/styles.css';
import { Button, ButtonGroup, Flex } from "@aws-amplify/ui-react";

export default function Home() {
  let [location, setLocation] = useState("");
  const [posX, setPosX] = useState(6);
  const [posY, setPosY] = useState(8);
  const running = useRef(null);

  let setup = () => {
    console.log("Hola");
    fetch("http://localhost:8000/simulations", {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    }).then(resp => resp.json())
    .then(data => {
      setLocation(data["Location"]);
      setPosX(data.agents[0].pos[0]-1);
      setPosY(data.agents[0].pos[1]-1);
  });
  }

  const handleStart = () => {
    running.current = setInterval(() => {
      fetch("http://localhost:8000" + location)
      .then(res => res.json())
      .then(data => {
        setPosX(data.agents[0].pos[0]-1);
        setPosY(data.agents[0].pos[1]-1);
      });
    }, 500);
  };

  const handleStop = () => {
    clearInterval(running.current);
  }

  return (
    <div className={styles.page}>
      <ButtonGroup variation="primary">
        <Button onClick={setup}>Setup</Button>
        <Button onClick={handleStart}>Start</Button>
        <Button onClick={handleStop}>Stop</Button>
      </ButtonGroup>
      <Flex direction={"column"}>
      <svg width="800" height="500" style={{backgroundColor: "lightgray"}} xmlns="http://www.w3.org/2000/svg">
        <image x={255 + 25 * posX} y={9 + 25 * posY} href="ghost.png"/>
      </svg>
      </Flex>
    </div>
  );
}