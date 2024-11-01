import os
import pygame
from pygame.locals import *
from math import sqrt
import numpy as np
import math

from OpenGL.GL import *
from OpenGL.GLU import *
from OpenGL.GLUT import *

# Importamos las clases personalizadas
from opmat import OpMat
from linea_bresenham import LineaBresenham3D

# Para integrar el código de Julia
from julia.api import Julia
jl = Julia(compiled_modules=False)
from julia import Main

Main.include("caja.jl")
Main.include("robot.jl")

ModuloCaja = Main.ModuloCaja
ModuloRobot = Main.ModuloRobot

screen_width = 700
screen_height = 700

FOVY = 51.0
ZNEAR = 0.01
ZFAR = 950.0

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

dimBoard = 250.0
zonaDescarga = 50.0

pygame.init()

robots = []
numRobots = 5

paquetes = []  # Son los paquetes de las cajas
npaquetes = 20

def lookAt():
    global EYE_X, EYE_Y, EYE_Z, CENTER_X, CENTER_Y, CENTER_Z, UP_X, UP_Y, UP_Z

    glLoadIdentity()
    gluLookAt(EYE_X, EYE_Y, EYE_Z, CENTER_X, CENTER_Y, CENTER_Z, UP_X, UP_Y, UP_Z)

def detectarColisionCaja():
    for robot in robots:
        if robot.estado_robot != "buscar":
            continue
        for paquete in paquetes:
            if paquete.estado_caja != "esperando":
                continue
            robotPos = robot.posicion
            cajaPos = paquete.posicion
            dist = sqrt((robotPos[0] - cajaPos[0]) ** 2 + (robotPos[1] - cajaPos[1]) ** 2)
            if dist < 10:
                ModuloRobot.transportar(robot, paquete)
                break

def dibujarPlano():
    opmat = OpMat()
    opmat.push()
    # Piso
    vertices = [
        (-dimBoard, -dimBoard, 0),
        (dimBoard, -dimBoard, 0),
        (dimBoard, dimBoard, 0),
        (-dimBoard, dimBoard, 0)
    ]
    transformed_vertices = opmat.mult_points(vertices)
    glColor3f(200 / 255, 200 / 255, 200 / 255)
    glBegin(GL_QUADS)
    for vertex in transformed_vertices:
        glVertex3f(*vertex)
    glEnd()

    # Zona de descarga
    vertices_zona = [
        (-dimBoard, -dimBoard, 0.1),
        (-dimBoard + 2 * zonaDescarga, -dimBoard, 0.1),
        (-dimBoard + 2 * zonaDescarga, -dimBoard + 2 * zonaDescarga, 0.1),
        (-dimBoard, -dimBoard + 2 * zonaDescarga, 0.1)
    ]
    transformed_vertices_zona = opmat.mult_points(vertices_zona)
    glColor3f(118 / 225, 132 / 225, 155 / 255)
    glBegin(GL_QUADS)
    for vertex in transformed_vertices_zona:
        glVertex3f(*vertex)
    glEnd()
    opmat.pop()

def dibujar_caja(caja):
    opmat = OpMat()
    opmat.push()
    opmat.translate(caja.posicion[0], caja.posicion[1], caja.posicion[2])
    opmat.rotate(np.degrees(caja.angulo), 0, 0, 1)
    opmat.scale(0.2, 0.2, 0.2)
    dibujar_caja_body(opmat)
    opmat.pop()

def dibujar_caja_body(opmat):
    # Obtener los vértices del cubo
    vertices = [
        (-10, -10, -10),
        (10, -10, -10),
        (10, 10, -10),
        (-10, 10, -10),
        (-10, -10, 10),
        (10, -10, 10),
        (10, 10, 10),
        (-10, 10, 10)
    ]

    # Transformar los vértices
    transformed_vertices = opmat.mult_points(vertices)

    # Dibujar líneas entre los vértices para formar el cubo
    edges = [
        (0,1), (1,2), (2,3), (3,0),  # Cara inferior
        (4,5), (5,6), (6,7), (7,4),  # Cara superior
        (0,4), (1,5), (2,6), (3,7)   # Conexiones verticales
    ]

    glColor3f(187 / 255, 156 / 255, 110 / 255)
    glBegin(GL_LINES)
    for edge in edges:
        for vertex in edge:
            glVertex3f(*transformed_vertices[vertex])
    glEnd()

def dibujar_robot(robot):
    opmat = OpMat()
    opmat.push()
    opmat.translate(robot.posicion[0], robot.posicion[1], robot.posicion[2])
    opmat.rotate(np.degrees(robot.angulo), 0, 0, 1)
    opmat.scale(0.2, 0.2, 0.2)
    dibujar_robot_body(opmat)
    dibujar_llantas_robot(opmat)
    opmat.pop()

def dibujar_robot_body(opmat):
    # Definir los vértices del cuerpo del robot (un cubo)
    vertices = [
        (-40, -20, -15),
        (40, -20, -15),
        (40, 20, -15),
        (-40, 20, -15),
        (-40, -20, 15),
        (40, -20, 15),
        (40, 20, 15),
        (-40, 20, 15)
    ]

    transformed_vertices = opmat.mult_points(vertices)

    edges = [
        (0,1), (1,2), (2,3), (3,0),
        (4,5), (5,6), (6,7), (7,4),
        (0,4), (1,5), (2,6), (3,7)
    ]

    glColor3f(30 / 255, 68 / 255, 168 / 255)
    glBegin(GL_LINES)
    for edge in edges:
        for vertex in edge:
            glVertex3f(*transformed_vertices[vertex])
    glEnd()

def dibujar_llantas_robot(opmat):
    # Definir las posiciones de las llantas
    posiciones_llantas = [
        (35, 20, -15),
        (-35, 20, -15),
        (35, -20, -15),
        (-35, -20, -15),
    ]

    for pos in posiciones_llantas:
        opmat.push()
        opmat.translate(pos[0], pos[1], pos[2])
        opmat.rotate(90, 0, 1, 0)
        # Dibujar la llanta como un círculo usando líneas
        glColor3f(52 / 255, 51 / 255, 51 / 255)
        glBegin(GL_LINE_LOOP)
        for i in range(20):
            theta = 2.0 * np.pi * i / 20
            x = 10 * np.cos(theta)
            y = 10 * np.sin(theta)
            glVertex3f(x, y, 0)
        glEnd()
        opmat.pop()

def Init():
    screen = pygame.display.set_mode(
        (screen_width, screen_height), DOUBLEBUF | OPENGL)
    pygame.display.set_caption("OpenGL: Robots")

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluPerspective(FOVY, screen_width / screen_height, ZNEAR, ZFAR)

    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    gluLookAt(EYE_X, EYE_Y, EYE_Z, CENTER_X, CENTER_Y, CENTER_Z,
              UP_X, UP_Y, UP_Z)
    glClearColor(0, 0, 0, 0)
    glEnable(GL_DEPTH_TEST)
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)

    global robots, paquetes
    robots = [ModuloRobot.crearRobot(dimBoard, zonaDescarga, 1.0)
              for _ in range(numRobots)]
    paquetes = [ModuloCaja.crearCaja(dimBoard, zonaDescarga)
                for _ in range(npaquetes)]

def display():
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    dibujarPlano()
    detectarColisionCaja()

    for robot in robots:
        dibujar_robot(robot)
        ModuloRobot.update(robot)
    for caja in paquetes:
        if caja.estado_caja != "soltada":
            dibujar_caja(caja)

def main():
    done = False
    Init()

    while not done:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                done = True

        display()
        pygame.display.flip()
        pygame.time.wait(30)

    pygame.quit()

if __name__ == '__main__':
    main()
