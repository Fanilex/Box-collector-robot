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

# Variables para la posición y rotación del carrito
car_pos_x = datos["agents"][0]["pos"][0] * 20 - 160  # Posición inicial
car_pos_y = datos["agents"][0]["pos"][1] * 20 - 160  # Posición inicial
rotation_angle = 0
move_speed = 5
rotation_speed = 5  # Velocidad de rotación gradual en grados por frame

X_MIN = -450
X_MAX = 450
Y_MIN = -270
Y_MAX = 270

def draw_circle(x, y, radius):
    glBegin(GL_LINE_LOOP)
    for i in range(100):
        angle = 2 * np.pi * i / 100
        glVertex2f(np.cos(angle) * radius + x, np.sin(angle) * radius + y)
    glEnd()

def draw_cart_top_view():
    glPushMatrix()
    glTranslatef(car_pos_x, car_pos_y, 0)
    glRotatef(rotation_angle, 0, 0, 1)

    glColor3f(0.0, 0.0, 1.0)
    glBegin(GL_QUADS)
    glVertex2f(-35, -25)
    glVertex2f(35, -25)
    glVertex2f(35, 25)
    glVertex2f(-35, 25)
    glEnd()

    glColor3f(0.0, 1.0, 0.0)
    draw_circle(-35, 20, 10)
    draw_circle(20, 20, 10)
    draw_circle(-35, -20, 10)
    draw_circle(20, -20, 10)

    glPopMatrix()

def update_position():
    global car_pos_x, car_pos_y
    # Realiza una solicitud para obtener la posición actualizada del agente
    response = requests.get(URL_BASE + LOCATION)
    datos = response.json()
    ghost = datos["agents"][0]
    car_pos_x = ghost["pos"][0] * 20 - 160
    car_pos_y = ghost["pos"][1] * 20 - 160

def init():
    screen = pygame.display.set_mode((screen_width, screen_height), DOUBLEBUF | OPENGL)
    pygame.display.set_caption("OpenGL: Carrito 2D (Vista desde arriba)")

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

    update_position()  # Actualiza la posición del carrito
    glClear(GL_COLOR_BUFFER_BIT)
    draw_cart_top_view()
    pygame.display.flip()
    pygame.time.wait(100)

pygame.quit()