import numpy as np

class OpMat:
    def __init__(self):
        self.M = np.identity(4)  # Matriz 4x4 para transformaciones 3D
        self.stack = []

    def translate(self, tx, ty, tz):
        T = np.array([[1, 0, 0, tx],
                      [0, 1, 0, ty],
                      [0, 0, 1, tz],
                      [0, 0, 0, 1]])
        self.M = self.M @ T

    def scale(self, sx, sy, sz):
        S = np.array([[sx, 0, 0, 0],
                      [0, sy, 0, 0],
                      [0, 0, sz, 0],
                      [0, 0, 0, 1]])
        self.M = self.M @ S

    def rotate(self, angle, x, y, z):
        rad = np.radians(angle)
        c = np.cos(rad)
        s = np.sin(rad)
        if x == 1:
            R = np.array([[1, 0, 0, 0],
                          [0, c, -s, 0],
                          [0, s, c, 0],
                          [0, 0, 0, 1]])
        elif y == 1:
            R = np.array([[c, 0, s, 0],
                          [0, 1, 0, 0],
                          [-s, 0, c, 0],
                          [0, 0, 0, 1]])
        elif z == 1:
            R = np.array([[c, -s, 0, 0],
                          [s, c, 0, 0],
                          [0, 0, 1, 0],
                          [0, 0, 0, 1]])
        else:
            R = np.identity(4)
        self.M = self.M @ R

    def loadIdentity(self):
        self.M = np.identity(4)

    def push(self):
        self.stack.append(self.M.copy())

    def pop(self):
        self.M = self.stack.pop()

    def mult_points(self, points):
        transformed_points = []
        for x, y, z in points:
            vec = np.array([x, y, z, 1])
            transformed_vec = self.M @ vec
            transformed_points.append(
                (transformed_vec[0], transformed_vec[1], transformed_vec[2]))
        return transformed_points
