import pygame
from pygame.locals import DOUBLEBUF, OPENGL
import requests
from OpenGL.GL import *
from OpenGL.GLU import *
from robot import Axis, draw_all_robots, update_positions

URL_BASE = "http://localhost:8000"
r = requests.post(URL_BASE + "/simulations", allow_redirects=False)
datos = r.json()
LOCATION = datos["Location"]

screen_width = 900
screen_height = 600

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

def update_api_positions():
    # Realiza una solicitud para obtener la posición actualizada del agente
    response = requests.get(URL_BASE + LOCATION)
    datos = response.json()
    ghost = datos["agents"][0]
    new_y = ghost["pos"][1] * 20 - 160
    update_positions(new_y)  # Actualiza la posición de los robots con el valor de Y

def main_loop():
    init()
    done = False
    while not done:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                done = True

        update_api_positions()
        glClear(GL_COLOR_BUFFER_BIT)
        Axis()
        draw_all_robots()
        pygame.display.flip()
        pygame.time.wait(100)

    pygame.quit()

if __name__ == "__main__":
    main_loop()
