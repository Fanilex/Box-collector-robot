import pygame
from pygame.locals import *
from OpenGL.GL import *
from OpenGL.GLU import *
import numpy as np
import requests


pygame.init()


URL_BASE = "http://localhost:8000"
r = requests.post(URL_BASE + "/simulations", allow_redirects=False)
datos = r.json()
LOCATION = datos["Location"]


screen_width = 900
screen_height = 600


# Variables para la posición de los robots
num_robots = 5
robot_spacing = 200  # Espaciado entre robots
total_width = (num_robots - 1) * robot_spacing  # Ancho total ocupado por los robots


# Posiciones iniciales para centrar los robots en la ventana
car_positions_x = [-(total_width / 2) + i * robot_spacing for i in range(num_robots)]
car_pos_y = datos["agents"][0]["pos"][1] * 20 - 160  # Posición vertical (compartida por todos)
rotation_angle = 0
move_speed = 5
rotation_speed = 5


# Limites de la ventana
X_MIN = -450
X_MAX = 450
Y_MIN = -270
Y_MAX = 270


def Axis():
   glShadeModel(GL_FLAT)
   glLineWidth(3.0)
   glColor3f(1.0, 0.0, 0.0)
   glBegin(GL_LINES)
   glVertex2f(X_MIN, 0.0)
   glVertex2f(X_MAX, 0.0)
   glEnd()
   glColor3f(0.0, 1.0, 0.0)
   glBegin(GL_LINES)
   glVertex2f(0.0, Y_MIN)
   glVertex2f(0.0, Y_MAX)
   glEnd()
   glLineWidth(1.0)


def draw_circle(x, y, radius):
   glBegin(GL_LINE_LOOP)
   for i in range(100):
       angle = 2 * np.pi * i / 100
       glVertex2f(np.cos(angle) * radius + x, np.sin(angle) * radius + y)
   glEnd()


def draw_robot(x, y, rotation_angle):
   glPushMatrix()
   glTranslatef(x, y, 0)
   glRotatef(rotation_angle, 0, 0, 1)


   # Dibuja el cuerpo del robot (cuadrado)
   glColor3f(0.0, 0.0, 1.0)
   glBegin(GL_QUADS)
   glVertex2f(-35, -25)
   glVertex2f(35, -25)
   glVertex2f(35, 25)
   glVertex2f(-35, 25)
   glEnd()


   # Dibuja las ruedas (círculos)
   glColor3f(0.0, 1.0, 0.0)
   draw_circle(-35, 20, 10)
   draw_circle(20, 20, 10)
   draw_circle(-35, -20, 10)
   draw_circle(20, -20, 10)


   glPopMatrix()


def draw_all_robots():
   for i in range(num_robots):
       draw_robot(car_positions_x[i], car_pos_y, rotation_angle)


def update_positions():
   global car_pos_y
   # Realiza una solicitud para obtener la posición actualizada del agente
   response = requests.get(URL_BASE + LOCATION)
   datos = response.json()
   ghost = datos["agents"][0]
   new_y = ghost["pos"][1] * 20 - 160


   # Asegúrate de que el movimiento esté contenido dentro de los límites verticales
   if Y_MIN < new_y < Y_MAX:
       car_pos_y = new_y  # Actualiza la posición si está dentro de los límites


def init():
   screen = pygame.display.set_mode((screen_width, screen_height), DOUBLEBUF | OPENGL)
   pygame.display.set_caption("OpenGL: Robots 2D (Vista desde arriba)")


   glMatrixMode(GL_PROJECTION)
   glLoadIdentity()
   gluOrtho2D(-450, 450, -300, 300)
   glMatrixMode(GL_MODELVIEW)
   glLoadIdentity()
   glClearColor(0, 0, 0, 0)
   glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
   glShadeModel(GL_FLAT)


init()


done = False
while not done:
   for event in pygame.event.get():
       if event.type == pygame.QUIT:
           done = True


   update_positions()  # Actualiza la posición de los robots
   glClear(GL_COLOR_BUFFER_BIT)
   Axis()
   draw_all_robots()
   pygame.display.flip()
   pygame.time.wait(100)


pygame.quit()

