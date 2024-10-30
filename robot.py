# Archivo: frontend.py

import socket
import json
import threading
import pygame
from pygame.locals import *
from OpenGL.GL import *
from OpenGL.GLU import *
import math

# Parámetros de la ventana
WIDTH, HEIGHT = 800, 600

# Estado global
estado = {"robots": [], "cajas": []}

# Variables para controlar la ventana de OpenGL
screen = None

def draw_circle(x, y, radius):
    segments = 32
    glBegin(GL_TRIANGLE_FAN)
    for i in range(segments + 1):
        theta = 2.0 * math.pi * i / segments
        dx = radius * math.cos(theta)
        dy = radius * math.sin(theta)
        glVertex2f(x + dx, y + dy)
    glEnd()

def draw_cart_top_view(x, y, rotation_angle, cargando):
    glPushMatrix()
    glTranslatef(x, y, 0)
    glRotatef(rotation_angle, 0, 0, 1)

    # Cuerpo del carro
    glColor3f(0.0, 0.0, 1.0)  # Azul
    glBegin(GL_QUADS)
    glVertex2f(-35, -25)
    glVertex2f(35, -25)
    glVertex2f(35, 25)
    glVertex2f(-35, 25)
    glEnd()

    # Ruedas
    glColor3f(0.0, 1.0, 0.0)  # Verde
    draw_circle(-35, 20, 10)
    draw_circle(35, 20, 10)
    draw_circle(-35, -20, 10)
    draw_circle(35, -20, 10)

    # Si está cargando, dibujar una caja encima
    if cargando:
        glColor3f(1.0, 0.5, 0.0)  # Naranja
        glBegin(GL_QUADS)
        glVertex2f(-15, 25)
        glVertex2f(15, 25)
        glVertex2f(15, 45)
        glVertex2f(-15, 45)
        glEnd()

    glPopMatrix()

def recibir_datos():
    global estado
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(('localhost', 5555))
    server.listen(1)
    conn, addr = server.accept()
    print("Conectado al backend en Julia")
    buffer = ""
    while True:
        data = conn.recv(1024).decode()
        if not data:
            break
        buffer += data
        while "\n" in buffer:
            mensaje, buffer = buffer.split("\n", 1)
            estado = json.loads(mensaje)
    conn.close()

def init_gl():
    glClearColor(1.0, 1.0, 1.0, 1.0)  # Fondo blanco
    glViewport(0, 0, WIDTH, HEIGHT)
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluOrtho2D(0, WIDTH, 0, HEIGHT)
    glMatrixMode(GL_MODELVIEW)

def dibujar_entorno():
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glLoadIdentity()

    # Dibujar zona de entrega
    glColor3f(0.0, 1.0, 0.0)  # Verde
    glBegin(GL_QUADS)
    glVertex2f(0, HEIGHT - 10)
    glVertex2f(WIDTH, HEIGHT - 10)
    glVertex2f(WIDTH, HEIGHT)
    glVertex2f(0, HEIGHT)
    glEnd()

    # Dibujar cajas
    for caja in estado.get("cajas", []):
        if not caja["recogida"]:
            x, y = caja["posicion"]
            x = x * 5
            y = y * 5
            glPushMatrix()
            glTranslatef(x, y, 0)
            glColor3f(1.0, 0.0, 0.0)  # Rojo
            glBegin(GL_QUADS)
            glVertex2f(-10, -10)
            glVertex2f(10, -10)
            glVertex2f(10, 10)
            glVertex2f(-10, 10)
            glEnd()
            glPopMatrix()

    # Dibujar robots
    for robot in estado.get("robots", []):
        x, y = robot["posicion"]
        x = x * 5
        y = y * 5
        cargando = robot["cargando"]
        # Calculamos el ángulo de rotación si es necesario
        rotation_angle = 0  # Por ahora lo dejamos en 0
        draw_cart_top_view(x, y, rotation_angle, cargando)

    pygame.display.flip()

def main():
    pygame.init()
    global screen
    screen = pygame.display.set_mode((WIDTH, HEIGHT), DOUBLEBUF | OPENGL)
    pygame.display.set_caption("Simulación de Robots")

    init_gl()

    # Iniciar hilo para recibir datos
    threading.Thread(target=recibir_datos, daemon=True).start()

    clock = pygame.time.Clock()
    running = True
    while running:
        clock.tick(30)  # FPS
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
        dibujar_entorno()
    pygame.quit()

if __name__ == "__main__":
    main()
