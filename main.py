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
total_lanes = 5  # Número de carriles
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
    
    # Draw the main floor (board) within margins
    vertices = [
        (-dimBoard + margin, -dimBoard + margin, 0),
        (dimBoard - margin, -dimBoard + margin, 0),
        (dimBoard - margin, dimBoard - margin, 0),
        (-dimBoard + margin, dimBoard - margin, 0)
    ]
    transformed_vertices = opmat.mult_points(vertices)
    glColor3f(200/255, 200/255, 200/255)  # Light grey color for the floor
    glBegin(GL_QUADS)
    for vertex in transformed_vertices:
        glVertex3f(*vertex)
    glEnd()
    
    # Dibujar carriles verticales dentro del área de interacción con márgenes
    lane_width = (2 * dimBoard - 2 * margin) / total_lanes  # Ajuste para márgenes
    glColor3f(1.0, 1.0, 1.0)  # Color blanco para las líneas de los carriles
    glLineWidth(2.0)
    glBegin(GL_LINES)
    for i in range(1, total_lanes):
        x = -dimBoard + margin + i * lane_width
        glVertex3f(x, -dimBoard + margin, 0.2)
        glVertex3f(x, dimBoard - margin, 0.2)
    glEnd()
    
    # Draw the drop-off zone within margins
    dropoff_vertices = [
        (-dimBoard + margin, dimBoard - zonaDescarga - margin, 0.5),  # Bottom left corner of drop-off zone
        (dimBoard - margin, dimBoard - zonaDescarga - margin, 0.5),   # Bottom right corner
        (dimBoard - margin, dimBoard - margin, 0.5),                  # Top right corner
        (-dimBoard + margin, dimBoard - margin, 0.5)                  # Top left corner
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


def check_full_stack(stack_index, robot_state):
    return robot_state["num_boxes_in_stacks"][stack_index] >= 5

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

    # Use color_override if provided; otherwise, default color
    if color_override:
        glColor3f(*color_override)
    else:
        glColor3f(187/255, 156/255, 110/255)  # Default box color
    
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
        # Round positions based on a tolerance to group into stacks
        stack_key = (round(x / STACK_TOLERANCE) * STACK_TOLERANCE,
                     round(y / STACK_TOLERANCE) * STACK_TOLERANCE)
        if stack_key not in stacks:
            stacks[stack_key] = []
        stacks[stack_key].append(package)

    # Determine which stacks are full
    full_stacks_keys = {key for key, packages in stacks.items() if len(packages) >= 5}

    # Draw packages
    for key, packages in stacks.items():
        is_full_stack = key in full_stacks_keys
        for package in packages:
            if is_full_stack:
                # Draw full stacks in red
                dibujar_caja(package, color_override=(1.0, 0.0, 0.0))  # Red color
            else:
                # Default color for other packages
                dibujar_caja(package)


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
           clock.tick(50)  # Increase to smooth out movement

    finally:
       simulation.cleanup()
       pygame.quit()


if __name__ == '__main__':
   main()