import std.stdio;
import std.outbuffer : OutBuffer;
import std.random : uniform;

import image : PNGWriter, Image, Color;

void main() {

    enum width = 50;
    enum height = 50;
    
    Image image = new Image(width, height);
    Color color;
    for(int x = 0; x < width; x++) {
        for(int y = 0; y < height; y++) {
            color.r = uniform(0f, 1f);
            color.g = uniform(0f, 1f);
            color.b = uniform(0f, 1f);
            image.setRGB(x, y, color);
        }
    }

    File file = File("render.png", "w");
    PNGWriter writer = new PNGWriter;
    writer.writeImage(image, file);

}