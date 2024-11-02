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

class SimulationState:
    def __init__(self):
        self.simulation_id = None
        self.robots_state = []
        self.packages_state = []
        self.api_url = "http://localhost:8000"
    
    def initialize_simulation(self, num_robots=5, num_packages=20):
        response = requests.post(
            f"{self.api_url}/simulation",
            json={"num_robots": num_robots, "num_packages": num_packages}
        )
        data = response.json()
        self.simulation_id = data["id"]
        self.robots_state = data["robots"]
        self.packages_state = data["packages"]
    
    def update(self):
        if not self.simulation_id:
            raise ValueError("Simulation ID not set. Make sure to initialize the simulation first.")
        
        response = requests.post(f"{self.api_url}/simulation/{self.simulation_id}")
        
        print("Response content:", response.content)  # Debug: check raw response content
        
        try:
            data = response.json()
            self.robots_state = data["robots"]
            self.packages_state = data["packages"]
        except json.JSONDecodeError:
            print("Failed to parse JSON. Response content:", response.content)
            data = None
        
        return data
    
    def cleanup(self):
        if self.simulation_id:
            requests.delete(f"{self.api_url}/simulation/{self.simulation_id}")


def dibujarPlano():
    opmat = OpMat()
    opmat.push()
    
    # Draw the main floor (board)
    vertices = [
        (-dimBoard, -dimBoard, 0),
        (dimBoard, -dimBoard, 0),
        (dimBoard, dimBoard, 0),
        (-dimBoard, dimBoard, 0)
    ]
    transformed_vertices = opmat.mult_points(vertices)
    glColor3f(200/255, 200/255, 200/255)  # Light grey color for the floor
    glBegin(GL_QUADS)
    print("Rendering drop-off zone...")
    for vertex in transformed_vertices:
        glVertex3f(*vertex)
    glEnd()
    
    # Draw the drop-off zone
    dropoff_vertices = [
        (-dimBoard, dimBoard - zonaDescarga, 0.5),  # Bottom left corner of drop-off zone
        (dimBoard, dimBoard - zonaDescarga, 0.5),   # Bottom right corner
        (dimBoard, dimBoard, 0.5),                  # Top right corner
        (-dimBoard, dimBoard, 0.5)                  # Top left corner
    ]
    transformed_dropoff_vertices = opmat.mult_points(dropoff_vertices)
    glColor3f(169/255, 169/255, 169/255)  # Dark grey color for the drop-off zone (change to red or yellow for testing)
    # Disable depth testing temporarily
    glDisable(GL_DEPTH_TEST)

    # Draw the drop-off zone
    glBegin(GL_QUADS)
    for vertex in transformed_dropoff_vertices:
        glVertex3f(*vertex)
    glEnd()

    # Re-enable depth testing
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

    glColor3f(30/255, 68/255, 168/255)
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
        glColor3f(52/255, 51/255, 51/255)
        glBegin(GL_LINE_LOOP)
        for i in range(20):
            theta = 2.0 * np.pi * i / 20
            x = 10 * np.cos(theta)
            y = 10 * np.sin(theta)
            glVertex3f(x, y, 0)
        glEnd()
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

    glColor3f(187/255, 156/255, 110/255)
    glBegin(GL_LINES)
    for edge in edges:
        for vertex in edge:
            glVertex3f(*transformed_vertices[vertex])
    glEnd()

def Init(simulation):  # Add simulation as parameter
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

def display(simulation):  # Add simulation as parameter
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    dibujarPlano()
    
    simulation.update()
    
    for robot_state in simulation.robots_state:
        dibujar_robot(robot_state)
    
    for package_state in simulation.packages_state:
        if package_state["state"] != "soltada":
            dibujar_caja(package_state)

def main():
    pygame.init()
    simulation = SimulationState()
    done = False
    Init(simulation)  # Pass simulation to Init

    clock = pygame.time.Clock()

    try:
        while not done:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    done = True

            display(simulation)  # Pass simulation to display
            pygame.display.flip()
            clock.tick(1)  # Increase to smooth out movement

    finally:
        simulation.cleanup()
        pygame.quit()

if __name__ == '__main__':
    main()
