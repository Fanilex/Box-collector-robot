import socket
import json
import threading
import pygame
from pygame.locals import *
from OpenGL.GL import *
from OpenGL.GLU import *
import math


WIDTH, HEIGHT = 800, 600


estado = {"robots": [], "cajas": [], "delivered_cajas": []}


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


   glColor3f(30 / 255, 68 / 255, 168 / 255)  # Azul
   glBegin(GL_QUADS)
   glVertex2f(-15, -10)
   glVertex2f(15, -10)
   glVertex2f(15, 10)
   glVertex2f(-15, 10)
   glEnd()


   glColor3f(52 / 255, 51 / 255, 51 / 255)  # Verde
   draw_circle(-15, 15, 5)
   draw_circle(15, 15, 5)
   draw_circle(-15, -15, 5)
   draw_circle(15, -15, 5)


   # Si está cargando, dibujar una caja encima
   if cargando:
       glColor3f(187 / 255, 156 / 255, 110 / 255)  # Naranja
       glBegin(GL_QUADS)
       glVertex2f(-10, 10)
       glVertex2f(10, 10)
       glVertex2f(10, 25)
       glVertex2f(-10, 25)
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
       data = conn.recv(4096).decode()
       if not data:
           break
       buffer += data
       while "\n" in buffer:
           mensaje, buffer = buffer.split("\n", 1)
           estado = json.loads(mensaje)
   conn.close()


def init_gl():
   glClearColor(200 / 255, 200 / 255, 200 / 255, 1.0)  # Fondo blanco
   glViewport(0, 0, WIDTH, HEIGHT)
   glMatrixMode(GL_PROJECTION)
   glLoadIdentity()
   gluOrtho2D(0, WIDTH, 0, HEIGHT)
   glMatrixMode(GL_MODELVIEW)


def dibujar_entorno():
   glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
   glLoadIdentity()


   # Dibujar zona de entrega
   glColor3f(118 / 255, 132 / 255, 155 / 255)  # Verde
   glBegin(GL_QUADS)
   glVertex2f(0, HEIGHT - 100)
   glVertex2f(WIDTH, HEIGHT - 100)
   glVertex2f(WIDTH, HEIGHT)
   glVertex2f(0, HEIGHT)
   glEnd()


   # Dibujar líneas entre carriles
   num_carriles = 5
   ancho_carril = WIDTH / num_carriles
   glColor3f(146 / 255, 142 / 255, 142 / 255)  # Negro
   glLineWidth(2)
   for i in range(1, num_carriles):
       x = i * ancho_carril
       glBegin(GL_LINES)
       glVertex2f(x, 0)
       glVertex2f(x, HEIGHT)
       glEnd()


   # Dibujar cajas en el grid
   for caja in estado.get("cajas", []):
       if not caja["recogida"]:
           x, y = caja["posicion"]
           x = (x / (ancho_carril * num_carriles)) * WIDTH
           y = (y / 100) * HEIGHT
           glPushMatrix()
           glTranslatef(x, y, 0)
           glColor3f(187 / 255, 156 / 255, 110 / 255)  # Naranja
           glBegin(GL_QUADS)
           glVertex2f(-5, -5)
           glVertex2f(5, -5)
           glVertex2f(5, 5)
           glVertex2f(-5, 5)
           glEnd()
           glPopMatrix()


   # Dibujar cajas entregadas en la zona de entrega (color naranja)
   for caja in estado.get("delivered_cajas", []):
       x, y = caja["posicion"]
       x = (x / (ancho_carril * num_carriles)) * WIDTH
       y = (y / 100) * HEIGHT
       glPushMatrix()
       glTranslatef(x, y, 0)
       glColor3f(187 / 255, 156 / 255, 110 / 255)  # Naranja
       glBegin(GL_QUADS)
       glVertex2f(-5, -5)
       glVertex2f(5, -5)
       glVertex2f(5, 5)
       glVertex2f(-5, 5)
       glEnd()
       glPopMatrix()


   # Dibujar robots
   for robot in estado.get("robots", []):
       x, y = robot["posicion"]
       x = (x / (ancho_carril * num_carriles)) * WIDTH
       y = (y / 100) * HEIGHT
       cargando = robot["cargando"]
       rotation_angle = 0
       draw_cart_top_view(x, y, rotation_angle, cargando)


   pygame.display.flip()


def main():
   pygame.init()
   global screen
   screen = pygame.display.set_mode((WIDTH, HEIGHT), DOUBLEBUF | OPENGL)
   pygame.display.set_caption("Simulación de Robots")


   init_gl()


   threading.Thread(target=recibir_datos, daemon=True).start()


   clock = pygame.time.Clock()
   running = True
   while running:
       clock.tick(60)
       for event in pygame.event.get():
           if event.type == pygame.QUIT:
               running = False
       dibujar_entorno()
   pygame.quit()


if __name__ == "__main__":
   main()