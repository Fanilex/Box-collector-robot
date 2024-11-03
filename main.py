#main
import os
import pygame
from pygame.locals import *
import numpy as np
import requests
import json

from OpenGL.GL import *
from OpenGL.GLU import *
from opmat import OpMat
from linea_bresenham import LineaBresenham3D  # Importar la función de Bresenham

# Parámetros de pantalla y simulación
STACK_TOLERANCE = 1.0
screen_width = 700
screen_height = 700

dimBoard = 150.0
zonaDescarga = 10.0
margin = 10.0    # Margen en unidades

# Definir parámetros de proyección ortográfica para 2D
ORTHO_LEFT = -dimBoard
ORTHO_RIGHT = dimBoard
ORTHO_BOTTOM = -dimBoard
ORTHO_TOP = dimBoard
ORTHO_NEAR = -1.0
ORTHO_FAR = 1.0

# Posición de la cámara 
EYE_X = 0.0
EYE_Y = 0.0
EYE_Z = 1.0 
CENTER_X = 0.0
CENTER_Y = 0.0
CENTER_Z = 0.0
UP_X = 0.0
UP_Y = 1.0
UP_Z = 0.0

class SimulationState:
    """Clase para gestionar el estado de la simulación."""
    def __init__(self):
        self.simulation_id = None
        self.robots_state = []
        self.packages_state = []
        self.api_url = "http://localhost:8000"
  
    def initialize_simulation(self, num_robots=5, num_packages=100):
        """Inicializa una nueva simulación con robots y cajas."""
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
        """Actualiza el estado de la simulación consultando la API."""
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
        """Limpia la simulación eliminándola de la API."""
        if self.simulation_id:
            requests.delete(f"{self.api_url}/simulation/{self.simulation_id}")

def dibujarPlano():
    """Función placeholder para dibujar el plano (actualmente vacía)."""
    opmat = OpMat()
    opmat.push()


    opmat.pop()

def dibujar_robot(robot_state):
    opmat = OpMat()
    opmat.push()
    posicion = robot_state["position"]
    angulo = robot_state["angle"]
    
    if len(posicion) == 2:
        x, y = posicion
        z = 0.0
    elif len(posicion) == 3:
        x, y, z = posicion
    else:
        raise ValueError("La posición debe tener 2 o 3 elementos.")
    
    opmat.translate(x, y, z)
    opmat.rotate(np.degrees(angulo), 0, 0, 1)
    opmat.scale(0.2, 0.2, 1.0)  # Escalar en X e Y solo
    dibujar_robot_body(opmat)
    opmat.pop()

def dibujar_robot_body(opmat):
    """Dibuja el cuerpo del robot como un rectángulo 2D utilizando Bresenham."""
    vertices = [
        (-40, -20, 0),
        (40, -20, 0),
        (40, 20, 0),
        (-40, 20, 0)
    ]

    # Transformar las coordenadas usando OpMat
    transformed_vertices = opmat.mult_points(vertices)  

    # Definir las aristas del rectángulo
    edges = [
        (0, 1),
        (1, 2),
        (2, 3),
        (3, 0)
    ]

    glColor3f(30/255, 68/255, 168/255)  # Color azul para los robots

    # Dibujar cada arista usando Bresenham
    for edge in edges:
        start = transformed_vertices[edge[0]]
        end = transformed_vertices[edge[1]]
        LineaBresenham3D(start[0], start[1], 0, end[0], end[1], 0)  # Dibujar línea usando Bresenham

def dibujar_caja(package_state, color_override=None):
    opmat = OpMat()
    opmat.push()
    posicion = package_state["position"]
    angulo = package_state["angle"]
    
    if len(posicion) == 2:
        x, y = posicion
        z = 0.0
    elif len(posicion) == 3:
        x, y, z = posicion
    else:
        raise ValueError("La posición debe tener 2 o 3 elementos.")
    
    opmat.translate(x, y, z)
    opmat.rotate(np.degrees(angulo), 0, 0, 1)
    opmat.scale(0.2, 0.2, 1.0)  # Escalar en X e Y solo
    dibujar_caja_body(opmat, color_override)
    opmat.pop()

def dibujar_caja_body(opmat, color_override=None):
    """Dibuja el contorno de una caja como un rectángulo 2D utilizando Bresenham."""
    # Definir los vértices de la caja (un rectángulo)
    vertices = [
        (-10, -10, 0),
        (10, -10, 0),
        (10, 10, 0),
        (-10, 10, 0)
    ]

    # Transformar las coordenadas usando OpMat
    transformed_vertices = opmat.mult_points(vertices) 

    # Definir las aristas de la caja
    edges = [
        (0, 1),
        (1, 2),
        (2, 3),
        (3, 0)
    ]

    # Establecer el color de la caja
    if color_override:
        glColor3f(*color_override)
    else:
        glColor3f(187/255, 156/255, 110/255)  # Color por defecto de las cajas

    # Dibujar cada arista usando Bresenham
    for edge in edges:
        start = transformed_vertices[edge[0]]
        end = transformed_vertices[edge[1]]
        LineaBresenham3D(start[0], start[1], 0, end[0], end[1], 0)  # Dibujar línea usando Bresenham

def Init(simulation):
    """Inicializa la ventana de Pygame y configura OpenGL."""
    screen = pygame.display.set_mode(
        (screen_width, screen_height), DOUBLEBUF | OPENGL)
    pygame.display.set_caption("OpenGL: Robots")

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    # Configurar proyección ortográfica para 2D
    gluOrtho2D(ORTHO_LEFT, ORTHO_RIGHT, ORTHO_BOTTOM, ORTHO_TOP)

    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()  # Cargar la identidad para 2D
    
    glClearColor(0, 0, 0, 0)  # Color de fondo negro
    glDisable(GL_DEPTH_TEST)  # Deshabilitar test de profundidad para 2D
    glEnable(GL_BLEND) 
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA) 
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)  # Modo de polígono relleno

    # Configurar tamaño de los puntos para visibilidad
    glPointSize(2.0)  # Puedes ajustar este valor según tus necesidades

    simulation.initialize_simulation()  # Iniciar simulación

def display(simulation):
    """Renderiza la escena de la simulación."""
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)  # Limpiar buffers
    dibujarPlano()  # Dibujar el plano de simulación
    
    simulation.update()  # Actualizar estado de la simulación

    # Dibujar todos los robots
    for robot_state in simulation.robots_state:
        dibujar_robot(robot_state)
        

    # Agrupar cajas en pilas según la tolerancia
    stacks = {}
    for package in simulation.packages_state:
        pos = package["position"]
        if len(pos) >= 2:
            x, y = pos[0], pos[1]
        else:
            print("Posición inválida:", pos)
            continue
        # Redondear posiciones para agrupar en pilas
        stack_key = (round(x / STACK_TOLERANCE) * STACK_TOLERANCE,
                    round(y / STACK_TOLERANCE) * STACK_TOLERANCE)
        if stack_key not in stacks:
            stacks[stack_key] = []
        stacks[stack_key].append(package)

    # Determinar el estado de cada pila
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
                dibujar_caja(package, color_override=(1.0, 0.0, 0.0))  # Rojo
            else:
                # Dibujar pilas disponibles en verde
                dibujar_caja(package, color_override=(0.0, 1.0, 0.0))  # Verde

def main():
    """Función principal que ejecuta la simulación."""
    pygame.init()  # Inicializar Pygame
    simulation = SimulationState()
    done = False
    Init(simulation)  # Configurar la simulación

    clock = pygame.time.Clock()  # Control de FPS

    try:
        while not done:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    done = True  # Salir del bucle principal

            display(simulation)  # Renderizar la simulación
            pygame.display.flip()  # Actualizar la pantalla
            clock.tick_busy_loop(100)  # Limitar a 60 FPS con mayor precisión

    finally:
        simulation.cleanup()  # Limpiar simulación al finalizar
        pygame.quit()  # Cerrar Pygame

if __name__ == '__main__':
    main()