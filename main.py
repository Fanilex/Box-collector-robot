import os
import pygame
from pygame.locals import *
from math import sqrt
import numpy as np
import requests
import json

from OpenGL.GL import *
from OpenGL.GLU import *
from opmat import OpMat
from linea_bresenham import LineaBresenham3D  # Importar la función de Bresenham

# Definición de variables globales
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
total_lanes = 5  # Número de carriles
margin = 20.0    # Margen en unidades

class SimulationState:
    def __init__(self):
        self.simulation_id = None
        self.robots_state = []
        self.packages_state = []
        self.api_url = "http://localhost:8000"
    
    def initialize_simulation(self, num_robots=5, num_packages=20):
        try:
            response = requests.post(
                f"{self.api_url}/simulation",
                json={"num_robots": num_robots, "num_packages": num_packages}
            )
            response.raise_for_status()
            data = response.json()
            self.simulation_id = data["id"]
            self.robots_state = data["robots"]
            self.packages_state = data["packages"]
            print(f"Simulation {self.simulation_id} initialized.")
        except requests.exceptions.RequestException as e:
            print(f"Failed to initialize simulation: {e}")
            self.simulation_id = None

        if len(self.robots_state) < num_robots:
            print(f"Warning: Expected {num_robots} robots, but only {len(self.robots_state)} were initialized.")
    
    def update(self):
        if not self.simulation_id:
            raise ValueError("Simulation ID not set. Make sure to initialize the simulation first.")
        
        try:
            response = requests.post(f"{self.api_url}/simulation/{self.simulation_id}")
            response.raise_for_status()
            data = response.json()
            self.robots_state = data["robots"]
            self.packages_state = data["packages"]
        except requests.exceptions.RequestException as e:
            print(f"Failed to update simulation: {e}")
            data = None
        except json.JSONDecodeError:
            print("Failed to parse JSON. Response content:", response.content)
            data = None
        
        return data
    
    def cleanup(self):
        if self.simulation_id:
            try:
                response = requests.delete(f"{self.api_url}/simulation/{self.simulation_id}")
                response.raise_for_status()
                print(f"Simulation {self.simulation_id} deleted.")
            except requests.exceptions.RequestException as e:
                print(f"Failed to delete simulation: {e}")

def dibujarPlano():
    opmat = OpMat()
    opmat.push()
    
    # Dibujar el piso principal dentro de los márgenes
    vertices = [
        (-dimBoard + margin, -dimBoard + margin, 0),
        (dimBoard - margin, -dimBoard + margin, 0),
        (dimBoard - margin, dimBoard - margin, 0),
        (-dimBoard + margin, dimBoard - margin, 0)
    ]
    transformed_vertices = opmat.mult_points(vertices)
    glColor3f(200/255, 200/255, 200/255)  # Gris claro para el piso
    glBegin(GL_QUADS)
    for vertex in transformed_vertices:
        glVertex3f(*vertex)
    glEnd()
    
    # Dibujar carriles verticales dentro del área de interacción con márgenes usando LineaBresenham3D
    lane_width = (2 * dimBoard - 2 * margin) / total_lanes  # Ajuste para márgenes
    glColor3f(1.0, 1.0, 1.0)  # Color blanco para las líneas de los carriles

    for i in range(1, total_lanes):
        x = -dimBoard + margin + i * lane_width
        y_start = -dimBoard + margin
        y_end = dimBoard - margin
        z = 0.2  # Altura constante para las líneas de carril
        LineaBresenham3D(x, y_start, z, x, y_end, z)
    
    # Dibujar la zona de descarga dentro de los márgenes
    dropoff_vertices = [
        (-dimBoard + margin, dimBoard - zonaDescarga - margin, 0.5),  # Esquina inferior izquierda
        (dimBoard - margin, dimBoard - zonaDescarga - margin, 0.5),   # Esquina inferior derecha
        (dimBoard - margin, dimBoard - margin, 0.5),                  # Esquina superior derecha
        (-dimBoard + margin, dimBoard - margin, 0.5)                  # Esquina superior izquierda
    ]
    transformed_dropoff_vertices = opmat.mult_points(dropoff_vertices)
    glColor3f(169/255, 169/255, 169/255)  # Gris oscuro para la zona de descarga
    
    # Desactivar la prueba de profundidad temporalmente
    glDisable(GL_DEPTH_TEST)

    # Dibujar la zona de descarga
    glBegin(GL_QUADS)
    for vertex in transformed_dropoff_vertices:
        glVertex3f(*vertex)
    glEnd()

    # Rehabilitar la prueba de profundidad
    glEnable(GL_DEPTH_TEST)
    
    opmat.pop()

def dibujar_robot(robot_state):
    opmat = OpMat()
    opmat.push()
    posicion = robot_state["position"]
    angulo = robot_state["angle"]
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

    edges = [
        (0,1), (1,2), (2,3), (3,0),
        (4,5), (5,6), (6,7), (7,4),
        (0,4), (1,5), (2,6), (3,7)
    ]

    glColor3f(30/255, 68/255, 168/255)  # Azul para el cuerpo del robot

    for edge in edges:
        v1 = transformed_vertices[edge[0]]
        v2 = transformed_vertices[edge[1]]
        LineaBresenham3D(v1[0], v1[1], v1[2], v2[0], v2[1], v2[2])

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
        glColor3f(52/255, 51/255, 51/255)  # Gris oscuro para las llantas

        # Definir los puntos de la llanta
        points = []
        for i in range(20):
            theta = 2.0 * np.pi * i / 20
            x = 10 * np.cos(theta)
            y = 10 * np.sin(theta)
            points.append((x, y, 0))

        # Dibujar líneas entre puntos consecutivos para formar el círculo
        for i in range(len(points)):
            v1 = points[i]
            v2 = points[(i + 1) % len(points)]  # Cerrar el loop
            LineaBresenham3D(v1[0], v1[1], v1[2], v2[0], v2[1], v2[2])

        opmat.pop()

def dibujar_caja(package_state):
    opmat = OpMat()
    opmat.push()
    posicion = package_state["position"]
    angulo = package_state["angle"]
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

    edges = [
        (0,1), (1,2), (2,3), (3,0),
        (4,5), (5,6), (6,7), (7,4),
        (0,4), (1,5), (2,6), (3,7)
    ]

    glColor3f(187/255, 156/255, 110/255)  # Marrón para las cajas

    for edge in edges:
        v1 = transformed_vertices[edge[0]]
        v2 = transformed_vertices[edge[1]]
        LineaBresenham3D(v1[0], v1[1], v1[2], v2[0], v2[1], v2[2])

def Init(simulation):
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

    simulation.initialize_simulation()

def display(simulation):
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    dibujarPlano()
    
    simulation.update()
    
    for robot_state in simulation.robots_state:
        dibujar_robot(robot_state)

    for package_state in simulation.packages_state:
        dibujar_caja(package_state)

def main():
    pygame.init()
    simulation = SimulationState()
    done = False
    Init(simulation)  # Pasar la simulación a Init

    clock = pygame.time.Clock()

    try:
        while not done:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    done = True

            display(simulation)  # Pasar la simulación a display
            pygame.display.flip()
            clock.tick(60)  # 60 FPS para una animación suave

    finally:
        simulation.cleanup()
        pygame.quit()

if __name__ == '__main__':
    main()
