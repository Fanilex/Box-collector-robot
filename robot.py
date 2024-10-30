# Archivo: frontend.py

import socket
import json
import threading
import pygame

# Parámetros de la ventana
WIDTH, HEIGHT = 500, 800
CELL_SIZE = 5  # Tamaño de cada celda en píxeles

# Colores
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
ROBOT_COLOR = (0, 0, 255)
CAJA_COLOR = (255, 0, 0)
CAJA_RECOGIDA_COLOR = (200, 200, 200)
ZONA_ENTREGA_COLOR = (0, 255, 0)

# Estado global
estado = {"robots": [], "cajas": []}

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

def dibujar_entorno(screen):
    screen.fill(WHITE)
    
    # Dibujar zona de entrega
    pygame.draw.rect(screen, ZONA_ENTREGA_COLOR, (0, 0, WIDTH, CELL_SIZE))
    
    # Dibujar cajas
    for caja in estado["cajas"]:
        if not caja["recogida"]:
            x, y = caja["posicion"]
            pygame.draw.rect(screen, CAJA_COLOR, (x * CELL_SIZE, HEIGHT - y * CELL_SIZE, CELL_SIZE, CELL_SIZE))
    
    # Dibujar robots
    for robot in estado["robots"]:
        x, y = robot["posicion"]
        color = ROBOT_COLOR if not robot["cargando"] else ZONA_ENTREGA_COLOR
        pygame.draw.circle(screen, color, (x * CELL_SIZE, HEIGHT - y * CELL_SIZE), CELL_SIZE)
    
    pygame.display.flip()

def main():
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Simulación de Robots")
    
    # Iniciar hilo para recibir datos
    threading.Thread(target=recibir_datos, daemon=True).start()
    
    clock = pygame.time.Clock()
    running = True
    while running:
        clock.tick(30)  # FPS
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
        dibujar_entorno(screen)
    pygame.quit()

if __name__ == "__main__":
    main()
