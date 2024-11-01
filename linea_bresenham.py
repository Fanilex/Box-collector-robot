from OpenGL.GL import *

def LineaBresenham3D(x1, y1, z1, x2, y2, z2):
    x1 = int(round(x1))
    y1 = int(round(y1))
    z1 = int(round(z1))
    x2 = int(round(x2))
    y2 = int(round(y2))
    z2 = int(round(z2))

    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    dz = abs(z2 - z1)
    xs = 1 if x2 > x1 else -1
    ys = 1 if y2 > y1 else -1
    zs = 1 if z2 > z1 else -1

    # Driving axis is X-axis
    if dx >= dy and dx >= dz:
        p1 = 2 * dy - dx
        p2 = 2 * dz - dx
        while x1 != x2:
            glBegin(GL_POINTS)
            glVertex3f(x1, y1, z1)
            glEnd()
            x1 += xs
            if p1 >= 0:
                y1 += ys
                p1 -= 2 * dx
            if p2 >= 0:
                z1 += zs
                p2 -= 2 * dx
            p1 += 2 * dy
            p2 += 2 * dz
    # Driving axis is Y-axis
    elif dy >= dx and dy >= dz:
        p1 = 2 * dx - dy
        p2 = 2 * dz - dy
        while y1 != y2:
            glBegin(GL_POINTS)
            glVertex3f(x1, y1, z1)
            glEnd()
            y1 += ys
            if p1 >= 0:
                x1 += xs
                p1 -= 2 * dy
            if p2 >= 0:
                z1 += zs
                p2 -= 2 * dy
            p1 += 2 * dx
            p2 += 2 * dz
    # Driving axis is Z-axis
    else:
        p1 = 2 * dy - dz
        p2 = 2 * dx - dz
        while z1 != z2:
            glBegin(GL_POINTS)
            glVertex3f(x1, y1, z1)
            glEnd()
            z1 += zs
            if p1 >= 0:
                y1 += ys
                p1 -= 2 * dz
            if p2 >= 0:
                x1 += xs
                p2 -= 2 * dz
            p1 += 2 * dy
            p2 += 2 * dx

    glBegin(GL_POINTS)
    glVertex3f(x2, y2, z2)
    glEnd()
