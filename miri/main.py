import os
import pygame
from pygame.locals import *
from math import sqrt
import numpy as np
import requests
from OpenGL.GL import *
from OpenGL.GLU import *
from opmat import OpMat

# Configuraciones iniciales
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

dimBoard = 250.0
zonaDescarga = 50.0
robots = list(range(5))  # IDs de robots
paquetes = list(range(20))  # IDs de paquetes

pygame.init()

# Función para llamar al servidor de robots
# Updated function for handling JSON response parsing
def call_julia_robot(action, id, caja_id=None):
    url = "http://127.0.0.1:8081"  # Robot server URL
    headers = {"Content-Type": "application/json"}
    data = {"action": action, "id": id}
    if caja_id is not None:
        data["caja_id"] = caja_id

    try:
        response = requests.post(url, headers=headers, json=data, timeout=5)  # Added timeout
        response.raise_for_status()
        try:
            # Attempt to parse JSON; if it fails, print response for debugging
            return response.json().get("result", None)
        except requests.exceptions.JSONDecodeError:
            print("Invalid JSON response:", response.text)  # Debugging output
            return None
    except requests.exceptions.RequestException as e:
        print("Error calling the robot server:", e)
        return None

# Updated function for handling JSON response parsing in caja server
def call_julia_caja(action, id, estado=None):
    url = "http://127.0.0.1:8082"  # Caja server URL
    headers = {"Content-Type": "application/json"}
    data = {"action": action, "id": id}
    if estado is not None:
        data["estado"] = estado

    try:
        response = requests.post(url, headers=headers, json=data, timeout=5)  # Added timeout
        response.raise_for_status()
        try:
            # Attempt to parse JSON; if it fails, print response for debugging
            return response.json().get("result", None)
        except requests.exceptions.JSONDecodeError:
            print("Invalid JSON response:", response.text)  # Debugging output
            return None
    except requests.exceptions.RequestException as e:
        print("Error calling the caja server:", e)
        return None

# Función para detectar colisión entre robots y paquetes
def detectarColisionCaja():
    for robot_id in robots:
        estado_robot = call_julia_robot("get_estado", robot_id)
        if estado_robot != "buscar":
            continue
        
        robotPos = call_julia_robot("get_posicion", robot_id)
        if robotPos is None:
            continue  # Saltar si no se obtuvo la posición

        for caja_id in paquetes:
            estado_caja = call_julia_caja("get_estado", caja_id)
            if estado_caja != "esperando":
                continue
            
            cajaPos = call_julia_caja("get_posicion", caja_id)
            if cajaPos is None:
                continue  # Saltar si no se obtuvo la posición de la caja

            # Calcular la distancia solo si ambas posiciones están definidas
            dist = sqrt((robotPos[0] - cajaPos[0]) ** 2 + (robotPos[1] - cajaPos[1]) ** 2)
            if dist < 10:
                call_julia_robot("transportar", robot_id, caja_id)
                break

# Resto del código como dibujarPlano, Init, display, y main no cambia

# Function to draw the ground plane
def dibujarPlano():
    opmat = OpMat()
    opmat.push()
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

    vertices_zona = [
        (-dimBoard, dimBoard - zonaDescarga, 0.1),
        (dimBoard, dimBoard - zonaDescarga, 0.1),
        (dimBoard, dimBoard, 0.1),
        (-dimBoard, dimBoard, 0.1)
    ]
    transformed_vertices_zona = opmat.mult_points(vertices_zona)
    glColor3f(118 / 225, 132 / 225, 155 / 255)
    glBegin(GL_QUADS)
    for vertex in transformed_vertices_zona:
        glVertex3f(*vertex)
    glEnd()
    opmat.pop()

# Function to draw a package
def dibujar_caja(caja_id):
    opmat = OpMat()
    opmat.push()
    posicion = call_julia_caja("get_posicion", caja_id)
    angulo = call_julia_caja("get_angulo", caja_id)
    if posicion is None or angulo is None:
        opmat.pop()
        return
    opmat.translate(posicion[0], posicion[1], posicion[2])
    opmat.rotate(np.degrees(angulo), 0, 0, 1)
    opmat.scale(0.2, 0.2, 0.2)
    dibujar_caja_body(opmat)
    opmat.pop()

def dibujar_caja_body(opmat):
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
    transformed_vertices = opmat.mult_points(vertices)
    edges = [(0,1), (1,2), (2,3), (3,0), (4,5), (5,6), (6,7), (7,4), (0,4), (1,5), (2,6), (3,7)]
    glColor3f(187 / 255, 156 / 255, 110 / 255)
    glBegin(GL_LINES)
    for edge in edges:
        for vertex in edge:
            glVertex3f(*transformed_vertices[vertex])
    glEnd()

# Function to draw a robot
def dibujar_robot(robot_id):
    opmat = OpMat()
    opmat.push()
    posicion = call_julia_robot("get_posicion", robot_id)
    angulo = call_julia_robot("get_angulo", robot_id)
    if posicion is None or angulo is None:
        opmat.pop()
        return
    opmat.translate(posicion[0], posicion[1], posicion[2])
    opmat.rotate(np.degrees(angulo), 0, 0, 1)
    opmat.scale(0.2, 0.2, 0.2)
    dibujar_robot_body(opmat)
    dibujar_llantas_robot(opmat)
    opmat.pop()

def dibujar_robot_body(opmat):
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
    edges = [(0,1), (1,2), (2,3), (3,0), (4,5), (5,6), (6,7), (7,4), (0,4), (1,5), (2,6), (3,7)]
    glColor3f(30 / 255, 68 / 255, 168 / 255)
    glBegin(GL_LINES)
    for edge in edges:
        for vertex in edge:
            glVertex3f(*transformed_vertices[vertex])
    glEnd()

def dibujar_llantas_robot(opmat):
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
        glColor3f(52 / 255, 51 / 255, 51 / 255)
        glBegin(GL_LINE_LOOP)
        for i in range(20):
            theta = 2.0 * np.pi * i / 20
            x = 10 * np.cos(theta)
            y = 10 * np.sin(theta)
            glVertex3f(x, y, 0)
        glEnd()
        opmat.pop()

# Initialize pygame and OpenGL
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

def display():
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    dibujarPlano()
    detectarColisionCaja()

    for robot_id in robots:
        call_julia_robot("update", robot_id)
        dibujar_robot(robot_id)
    for caja_id in paquetes:
        estado_caja = call_julia_caja("get_estado", caja_id)
        if estado_caja != "soltada":
            dibujar_caja(caja_id)

# Main loop
def main():
    Init()
    clock = pygame.time.Clock()
    done = False

    while not done:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                done = True

        display()
        pygame.display.flip()
        clock.tick(60)  # Limit to 60 FPS for smooth animation

    pygame.quit()

if __name__ == '__main__':
    main()