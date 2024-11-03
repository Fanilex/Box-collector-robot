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

STACK_TOLERANCE = 1.0
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
margin = 20.0    # Margen en unidades

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

      if len(self.robots_state) < num_robots:
          print(f"Warning: Expected {num_robots} robots, but only {len(self.robots_state)} were initialized.")
  
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
    
    # Dibujar el piso principal dentro de los márgenes
    vertices = [
        (-dimBoard + margin, -dimBoard + margin, 0),
        (dimBoard - margin, -dimBoard + margin, 0),
        (dimBoard - margin, dimBoard - margin, 0),
        (-dimBoard + margin, dimBoard - margin, 0)
    ]
    transformed_vertices = opmat.mult_points(vertices)
    glColor3f(200/255, 200/255, 200/255)  # Color gris claro para el piso
    glBegin(GL_QUADS)
    for vertex in transformed_vertices:
        glVertex3f(*vertex)
    glEnd()
    
    # No dibujar carriles

    # Dibujar la zona de descarga con un color base
    dropoff_vertices = [
        (-dimBoard + margin, dimBoard - zonaDescarga - margin, 0.5),  # Esquina inferior izquierda de la zona de descarga
        (dimBoard - margin, dimBoard - zonaDescarga - margin, 0.5),   # Esquina inferior derecha
        (dimBoard - margin, dimBoard - margin, 0.5),                  # Esquina superior derecha
        (-dimBoard + margin, dimBoard - margin, 0.5)                  # Esquina superior izquierda
    ]
    transformed_dropoff_vertices = opmat.mult_points(dropoff_vertices)
    glColor3f(0.5, 0.5, 0.5)  # Color gris medio para la zona de descarga
    # Deshabilitar temporalmente el test de profundidad
    glDisable(GL_DEPTH_TEST)

    # Dibujar la zona de descarga
    glBegin(GL_QUADS)
    for vertex in transformed_dropoff_vertices:
        glVertex3f(*vertex)
    glEnd()

    # Rehabilitar el test de profundidad
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

   glColor3f(30/255, 68/255, 168/255)  # Color azul para los robots
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
       glColor3f(52/255, 51/255, 51/255)  # Color gris oscuro para las llantas
       glBegin(GL_LINE_LOOP)
       for i in range(20):
           theta = 2.0 * np.pi * i / 20
           x = 10 * np.cos(theta)
           y = 10 * np.sin(theta)
           glVertex3f(x, y, 0)
       glEnd()
       opmat.pop()

def dibujar_caja(package_state, color_override=None):
    opmat = OpMat()
    opmat.push()
    posicion = package_state["position"]
    angulo = package_state["angle"]
    opmat.translate(posicion[0], posicion[1], posicion[2])
    opmat.rotate(np.degrees(angulo), 0, 0, 1)
    opmat.scale(0.2, 0.2, 0.2)
    dibujar_caja_body(opmat, color_override)
    opmat.pop()

def dibujar_caja_body(opmat, color_override=None):
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

    # Usar color_override si se proporciona; de lo contrario, color por defecto
    if color_override:
        glColor3f(*color_override)
    else:
        glColor3f(187/255, 156/255, 110/255)  # Color por defecto de las cajas
    
    glBegin(GL_LINES)
    for edge in edges:
        for vertex in edge:
            glVertex3f(*transformed_vertices[vertex])
    glEnd()

def Init(simulation):  # Agregar simulation como parámetro
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

    stacks = {}
    for package in simulation.packages_state:
        pos = package["position"]
        x, y = pos[0], pos[1]
        # Redondear posiciones según una tolerancia para agrupar en pilas
        stack_key = (round(x / STACK_TOLERANCE) * STACK_TOLERANCE,
                     round(y / STACK_TOLERANCE) * STACK_TOLERANCE)
        if stack_key not in stacks:
            stacks[stack_key] = []
        stacks[stack_key].append(package)

    # Determinar el estado de las pilas
    stack_colors = {}
    for key, packages in stacks.items():
        if len(packages) >= 5:
            stack_colors[key] = (1.0, 0.0, 0.0)  # Rojo para pilas llenas
        elif len(packages) > 0:
            stack_colors[key] = (0.0, 1.0, 0.0)  # Verde para pilas disponibles

    # Dibujar cajas con color basado en el estado de la pila
    for key, packages in stacks.items():
        is_full_stack = len(packages) >= 5
        for package in packages:
            if is_full_stack:
                # Dibujar pilas llenas en rojo
                dibujar_caja(package, color_override=(1.0, 0.0, 0.0))  # Color rojo
            else:
                # Dibujar pilas disponibles en verde
                dibujar_caja(package, color_override=(0.0, 1.0, 0.0))  # Color verde

def main():
    pygame.init()
    simulation = SimulationState()
    done = False
    Init(simulation)  # Pasar simulation a Init

    clock = pygame.time.Clock()

    try:
       while not done:
           for event in pygame.event.get():
               if event.type == pygame.QUIT:
                   done = True

           display(simulation)  # Pasar simulation a display
           pygame.display.flip()
           clock.tick(10)  # Aumentar para suavizar el movimiento

    finally:
       simulation.cleanup()
       pygame.quit()

if __name__ == '__main__':
   main()
