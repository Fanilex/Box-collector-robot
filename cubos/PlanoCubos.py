#Autor: Ivan Olmos Pineda
#Curso: Multiagentes - Graficas Computacionales

import pygame
from pygame.locals import *

# Cargamos las bibliotecas de OpenGL
from OpenGL.GL import *
from OpenGL.GLU import *
from OpenGL.GLUT import *

# Se carga el archivo de la clase Cubo
from Cubo import Cubo


import requests

URL_BASE = "http://localhost:8000"
r = requests.post(URL_BASE+ "/simulations", allow_redirects=False)
datos = r.json()
print(datos)
LOCATION = datos["Location"]
initialX = datos["agents"][0]["pos"][0]
initialY = datos["agents"][0]["pos"][1]

screen_width = 500
screen_height = 500
#vc para el obser.
FOVY=60.0
ZNEAR=0.01
ZFAR=900.0
#Variables para definir la posicion del observador
#gluLookAt(EYE_X,EYE_Y,EYE_Z,CENTER_X,CENTER_Y,CENTER_Z,UP_X,UP_Y,UP_Z)
EYE_X=300.0
EYE_Y=200.0
EYE_Z=300.0
CENTER_X=0
CENTER_Y=0
CENTER_Z=0
UP_X=0
UP_Y=1
UP_Z=0
#Variables para dibujar los ejes del sistema
X_MIN=-500
X_MAX=500
Y_MIN=-500
Y_MAX=500
Z_MIN=-500
Z_MAX=500
#Dimension del plano
DimBoard = 200

pygame.init()

cubo = Cubo(0, 0)

def Init():
    pygame.display.set_mode(
        (screen_width, screen_height), DOUBLEBUF | OPENGL)
    pygame.display.set_caption("OpenGL: cubos")

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluPerspective(FOVY, screen_width/screen_height, ZNEAR, ZFAR)

    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    gluLookAt(EYE_X,EYE_Y,EYE_Z,CENTER_X,CENTER_Y,CENTER_Z,UP_X,UP_Y,UP_Z)
    glClearColor(0,0,0,0)
    glEnable(GL_DEPTH_TEST)
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
    
def display():
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    #Se dibuja el plano gris
    glColor3f(0.3, 0.3, 0.3)
    glBegin(GL_QUADS)
    glVertex3d(-DimBoard, 0, -DimBoard)
    glVertex3d(-DimBoard, 0, DimBoard)
    glVertex3d(DimBoard, 0, DimBoard)
    glVertex3d(DimBoard, 0, -DimBoard)
    glEnd()
    #Se dibuja cubos
    cubo.draw()

    response = requests.get(URL_BASE + LOCATION)
    datos = response.json()
    ghost = datos["agents"][0]
    cubo.update(ghost["pos"][0] * 20 - 160, ghost["pos"][1] * 20 - 160)
    
done = False
Init()
while not done:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            done = True

    display()

    pygame.display.flip()
    pygame.time.wait(500)

pygame.quit()