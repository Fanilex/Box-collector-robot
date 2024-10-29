import pygame
from OpenGL.GL import *
from OpenGL.GLU import *
import numpy as np

X_MIN = -450
X_MAX = 450
Y_MIN = -300
Y_MAX = 300

num_robots = 5
robot_spacing = 200
total_width = (num_robots - 1) * robot_spacing 
car_positions_x = [-(total_width / 2) + i * robot_spacing for i in range(num_robots)]
car_pos_y = 0 
rotation_angle = 0

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

def draw_all_robots():
    for i in range(num_robots):
        draw_robot(car_positions_x[i], car_pos_y, rotation_angle)

def update_positions(new_y):
    global car_pos_y
    if Y_MIN < new_y < Y_MAX:
        car_pos_y = new_y