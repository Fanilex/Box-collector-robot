import pygame
from pygame.locals import *
from math import sqrt
import numpy as np

from OpenGL.GL import *
from OpenGL.GLU import *
from julia.api import Julia
jl = Julia(compiled_modules=False)
from julia import Main

# Load Julia files
Main.include("caja.jl")
Main.include("robot.jl")

ModuloCaja = Main.ModuloCaja
ModuloRobot = Main.ModuloRobot

# Screen and camera settings
screen_width, screen_height = 700, 700
dimBoard, zonaDescarga = 250.0, 50.0
FOVY, ZNEAR, ZFAR = 51.0, 0.01, 950.0

# Initialize pygame
pygame.init()
screen = pygame.display.set_mode((screen_width, screen_height), DOUBLEBUF | OPENGL)
pygame.display.set_caption("OpenGL: Robots")

# Initialize OpenGL
glMatrixMode(GL_PROJECTION)
glLoadIdentity()
gluPerspective(FOVY, screen_width / screen_height, ZNEAR, ZFAR)
glMatrixMode(GL_MODELVIEW)
glLoadIdentity()
gluLookAt(0, 0, 510, 0, 0, 0, 0, 1, 0)
glClearColor(0, 0, 0, 0)
glEnable(GL_DEPTH_TEST)

# Initialize robots and packages
robots = [ModuloRobot.crearRobot(dimBoard, zonaDescarga, 1.0) for _ in range(5)]
paquetes = [ModuloCaja.crearCaja(dimBoard, zonaDescarga) for _ in range(20)]

def lookAt():
    """Resets camera view."""
    glLoadIdentity()
    gluLookAt(0, 0, 510, 0, 0, 0, 0, 1, 0)

def detectarColisionCaja():
    """Detects collisions between robots and packages."""
    for robot in robots:
        if robot.estado_robot != "buscar":
            continue
        for paquete in paquetes:
            if paquete.estado_caja != "esperando":
                continue
            robotPos, cajaPos = robot.posicion, paquete.posicion
            if sqrt((robotPos[0] - cajaPos[0])**2 + (robotPos[1] - cajaPos[1])**2) < 10:
                ModuloRobot.transportar(robot, paquete)
                break

def dibujarPlano():
    """Draws the ground plane and download zone."""
    glColor3f(0.78, 0.78, 0.78)
    glBegin(GL_QUADS)
    glVertex3f(-dimBoard, -dimBoard, 0)
    glVertex3f(dimBoard, -dimBoard, 0)
    glVertex3f(dimBoard, dimBoard, 0)
    glVertex3f(-dimBoard, dimBoard, 0)
    glEnd()

    # Download zone
    glColor3f(0.46, 0.52, 0.61)
    glBegin(GL_QUADS)
    glVertex3f(-dimBoard, -dimBoard, 0.1)
    glVertex3f(-dimBoard + 2 * zonaDescarga, -dimBoard, 0.1)
    glVertex3f(-dimBoard + 2 * zonaDescarga, -dimBoard + 2 * zonaDescarga, 0.1)
    glVertex3f(-dimBoard, -dimBoard + 2 * zonaDescarga, 0.1)
    glEnd()

def dibujar_caja(caja):
    """Draws a package (caja)."""
    glColor3f(0.73, 0.61, 0.43)
    glBegin(GL_QUADS)
    for dx, dy in [(-10, -10), (10, -10), (10, 10), (-10, 10)]:
        glVertex3f(caja.posicion[0] + dx, caja.posicion[1] + dy, caja.posicion[2])
    glEnd()

def dibujar_robot(robot):
    """Draws a robot."""
    glColor3f(0.12, 0.27, 0.66)
    glBegin(GL_QUADS)
    for dx, dy in [(-20, -10), (20, -10), (20, 10), (-20, 10)]:
        glVertex3f(robot.posicion[0] + dx, robot.posicion[1] + dy, robot.posicion[2])
    glEnd()

def display():
    """Main display function for rendering the scene."""
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    dibujarPlano()
    detectarColisionCaja()

    # Draw robots and update them using Julia's ModuloRobot
    for robot in robots:
        dibujar_robot(robot)
        ModuloRobot.update(robot)
    
    # Draw packages
    for caja in paquetes:
        if caja.estado_caja != "soltada":
            dibujar_caja(caja)

def main():
    """Main control loop."""
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

        display()
        pygame.display.flip()
        pygame.time.wait(30)

    pygame.quit()

if __name__ == '__main__':
    main()