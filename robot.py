import pygame
import numpy as np

# Configuración de pantalla
X_MIN, X_MAX = -450, 450
Y_MIN, Y_MAX = -300, 300
SCREEN_WIDTH, SCREEN_HEIGHT = X_MAX - X_MIN, Y_MAX - Y_MIN

# Configuración de color
WHITE = (255, 255, 255)
BLUE = (0, 0, 255)
GREEN = (0, 255, 0)

# Inicializar Pygame
pygame.init()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Simulación de Robot y Caja")

# Definir posiciones iniciales
robot_pos = np.array([SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2])
caja_pos = np.array([np.random.randint(0, SCREEN_WIDTH), np.random.randint(0, SCREEN_HEIGHT)])
running = True

def draw_robot(position):
    pygame.draw.rect(screen, BLUE, (*position - np.array([35, 25]), 70, 50))

def draw_caja(position):
    pygame.draw.circle(screen, GREEN, position, 10)

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    # Limpiar pantalla
    screen.fill(WHITE)

    # Dibujar robot y caja
    draw_robot(robot_pos)
    draw_caja(caja_pos)

    # Actualizar pantalla
    pygame.display.flip()

pygame.quit()
