import os
os.chdir("/Users/sofiazugasti/Desktop/Sitemas_multiagentes/Box-collector-robot/miri")
import pygame
from pygame.locals import *
from math import sqrt
import numpy as np
import math

from OpenGL.GL import *
from OpenGL.GLU import *
from OpenGL.GLUT import *
#hola

# para jalar el codigo de julia
from julia.api import Julia
jl = Julia(compiled_modules=False)
from julia import Main

Main.include("caja.jl")
Main.include("robot.jl")

ModuloCaja = Main.ModuloCaja
ModuloRobot = Main.ModuloRobot

screen_width = 700
screen_height = 700
# Variables de la cámara
FOVY = 51.0
ZNEAR = 0.01
ZFAR = 950.0
# Posición del observador
EYE_X = 0.0
EYE_Y = 0.0
EYE_Z = 510.0
CENTER_X = 0.0
CENTER_Y = 0.0
CENTER_Z = 0.0
UP_X = 0.0
UP_Y = 1.0
UP_Z = 0.0

X_MIN = -500
X_MAX = 500
Y_MIN = -500
Y_MAX = 500
Z_MIN = -500
Z_MAX = 500

# Variables para el control de la vista
radius = sqrt((pow(EYE_X, 2) + pow(EYE_Y, 2)))
theta = 45

dimBoard = 250.0
zonaDescarga = 50.0

pygame.init()

robots = []
numRobots = 5

pi = 3.14159265359

paquetes = []
npaquetes = 20

def lookAt():
    global EYE_X, EYE_Y, EYE_Z, CENTER_X, CENTER_Y, CENTER_Z, UP_X, UP_Y, UP_Z
        
    glLoadIdentity()
    gluLookAt(EYE_X, EYE_Y, EYE_Z, CENTER_X, CENTER_Y, CENTER_Z, UP_X, UP_Y, UP_Z)

def palletCajaCollision():
    for robot in robots:
        if robot.actividad != "buscar":
            continue
        for paquete in paquetes:
            if paquete.estado != "FREE":
                continue
            robotPos = robot.posicion
            cajaPos = paquete.posicion
            dist = sqrt((robotPos[0] - cajaPos[0]) ** 2 + (robotPos[1] - cajaPos[1]) ** 2)
            if dist < 20:
                ModuloRobot.transportar(robot, paquete)
                break

def drawFloor():
    # Dibuja el piso
    glColor3f(200 / 255, 200 / 255, 200 / 255)
    glBegin(GL_QUADS)
    glVertex3d(-dimBoard, -dimBoard, 0)
    glVertex3d(dimBoard, -dimBoard, 0)
    glVertex3d(dimBoard, dimBoard, 0)
    glVertex3d(-dimBoard, dimBoard, 0)
    glEnd()
    
    # Dibujar las divisiones
    glColor3f(0.0, 0.0, 0.0)  
    glLineWidth(2.0) 

    zona_ancho = dimBoard * 2 
    recuadro_ancho = zona_ancho / 5  

    glBegin(GL_LINES)
    for i in range(1, 5):
        x_pos = -dimBoard + i * recuadro_ancho  
        glVertex3d(x_pos, dimBoard - 2 * zonaDescarga, 0.1)  
        glVertex3d(x_pos, dimBoard, 0.1)  
    glEnd()

    # Zona de recolección en la esquina inferior izquierda
    glColor3f(118 / 225, 132 / 225, 155 / 255)
    glBegin(GL_QUADS)
    glVertex3d(-dimBoard, dimBoard - 2 * zonaDescarga, 0.1) 
    glVertex3d(dimBoard, dimBoard - 2 * zonaDescarga, 0.1)  
    glVertex3d(dimBoard, dimBoard, 0.1)  
    glVertex3d(-dimBoard, dimBoard, 0.1)  
    glEnd()

def Init():
    screen = pygame.display.set_mode(
        (screen_width, screen_height), DOUBLEBUF | OPENGL)
    pygame.display.set_caption("OpenGL: Robots")

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluPerspective(FOVY, screen_width / screen_height, ZNEAR, ZFAR)

    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    gluLookAt(EYE_X, EYE_Y, EYE_Z, CENTER_X, CENTER_Y, CENTER_Z, UP_X, UP_Y, UP_Z)
    glClearColor(0, 0, 0, 0)
    glEnable(GL_DEPTH_TEST)
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)

    global robots, paquetes
    robots = [ModuloRobot.crearRobot(dimBoard, zonaDescarga, 1.0, i+1) for i in range(numRobots)]
    paquetes = [ModuloCaja.crearCaja(dimBoard, zonaDescarga) for _ in range(npaquetes)]

def draw_caja(caja):
    glPushMatrix()
    glTranslatef(caja.posicion[0], caja.posicion[1], caja.posicion[2])
    glScaled(0.2, 0.2, 0.2)
    glRotatef(np.degrees(caja.angulo), 0, 0, 1)
    draw_caja_body()
    glPopMatrix()

def draw_caja_body():
    # caja
    glColor3f(187 / 255, 156 / 255, 110 / 255)
    glutSolidCube(20)

def draw_robot(robot):
    glPushMatrix()
    glTranslatef(robot.posicion[0], robot.posicion[1], robot.posicion[2])
    glRotatef(np.degrees(robot.angulo), 0, 0, 1)
    glScaled(0.2, 0.2, 0.2)

    draw_robot_body()
    draw_robot_wheels()

    glPopMatrix()

def draw_robot_body():
    # robot
    glColor3f(30 / 255, 68 / 255, 168 / 255)
    glPushMatrix()
    glScalef(80, 40, 30)
    glutSolidCube(1)
    glPopMatrix()

def draw_robot_wheels():
    # llantas
    glColor3f(52 / 255, 51 / 255, 51 / 255)
    wheel_radius = 10
    wheel_width = 5

    wheel_posiciones = [
        (35, 20, -15),  # Front right
        (-35, 20, -15),  # Rear right
        (35, -20, -15),  # Front left
        (-35, -20, -15),  # Rear left
    ]

    for pos in wheel_posiciones:
        glPushMatrix()
        glTranslatef(pos[0], pos[1], pos[2])
        glRotatef(90, 0, 1, 0)
        glutSolidTorus(wheel_width / 2, wheel_radius, 12, 12)
        glPopMatrix()

def display():
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    drawFloor()

    palletCajaCollision()

    for robot in robots:
        draw_robot(robot)
        ModuloRobot.update(robot)
    for caja in paquetes:
        draw_caja(caja)

def main():
    done = False
    Init()

    global theta

    while not done:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                done = True
        keys = pygame.key.get_pressed()
        if keys[K_RIGHT]:
            if theta > 359.0:
                theta = 0.0
            else:
                theta += 1.0
            lookAt()
        if keys[K_LEFT]:
            if theta < 1.0:
                theta = 360.0
            else:
                theta -= 1.0
            lookAt()

        display()
        pygame.display.flip()
        pygame.time.wait(10)

    pygame.quit()

if __name__ == '__main__':
    main()