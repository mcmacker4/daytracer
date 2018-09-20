import std.stdio : File, writefln;
import std.bitmanip : nativeToBigEndian;
import std.zlib : crc32, compress;
import std.outbuffer : OutBuffer;
import std.math : floor;

struct Color {
    
    float r = 0f;
    float g = 0f;
    float b = 0f;
    float a = 1f;

    uint toPixel() const {
        immutable uint ir = cast(uint) floor(r * 0xFF) & 0xFF;
        immutable uint ig = cast(uint) floor(g * 0xFF) & 0xFF;
        immutable uint ib = cast(uint) floor(b * 0xFF) & 0xFF;
        immutable uint ia = cast(uint) floor(a * 0xFF) & 0xFF;
        return (ir << 24) | (ig << 16) | (ib << 8) | ia;
    }

}

/**
    Image Class
*/
class Image {

    private int width;
    private int height;

    private uint[] data;

    /**
        Create empty image
    */
    this(int width, int height) {
        this.width = width;
        this.height = height;
        this.data = new uint[width * height];
    }

    void setRGB(int x, int y, uint c) {
        this.data[y * width + x] = c;
    }

    void setRGB(int x, int y, const ref Color color) {
        this.setRGB(x, y, color.toPixel);
    }

    int getRGB(int x, int y) const {
        return data[y * width + x];
    }

    int getWidth() const {
        return width;
    }

    int getHeight() const {
        return height;
    }

}

private class CRC {

    private static uint[256] table;

    this() {
        throw new Exception("CRC is a static class. Do not instanciate.");
    }

    static this() {
        uint c;
        for(uint n = 0; n < 256; n++) {
            c = n;
            for(uint k = 0; k < 8; k++) {
                if(c & 1)
                    c = 0xedb88320 ^ (c >> 1);
                else
                    c = c >> 1;
            }
            table[n] = c;
        }
    }

    private static uint digest(uint crc, const ubyte[] data) {
        uint c = crc;
        for(uint n = 0; n < data.length; n++) {
            c = table[(c ^ data[n]) & 0xFF] ^ (c >> 8);
        }
        return c;
    }

    static uint crc(const ubyte[] data) {
        return digest(0xFFFFFFFF, data) ^ 0xFFFFFFFF;
    }

}

/**
    PNG Writer
*/
class PNGWriter {

    private OutBuffer buf = new OutBuffer;

    private uint crc(ubyte[] data) {
        return CRC.crc(data);
    }

    private void writePacket(ubyte[] data, uint length, ref File file) {
        file.rawWrite(length.nativeToBigEndian);
        file.rawWrite(data);
        file.rawWrite(crc(data).nativeToBigEndian);
    }

    private void writeIHDR(const Image image, ref File file) {
        buf.write("IHDR");
        //Image size
        buf.write(image.width.nativeToBigEndian);
        buf.write(image.height.nativeToBigEndian);
        // [ bit depth, color type, compression, filter method, interlace ]
        buf.write(cast(ubyte[]) [ 8, 6, 0, 0, 0 ]);

        writePacket(buf.toBytes, 13, file);
        buf.clear;
    }

    private void writeIDAT(const Image image, ref File file) {

        ubyte[4] pixel;

        void getPixel(const uint color, out ubyte[4] pixel) {
            pixel[0] = cast(ubyte) ((color >> 24) & 0xFF);
            pixel[1] = cast(ubyte) ((color >> 16) & 0xFF);
            pixel[2] = cast(ubyte) ((color >>  8) & 0xFF);
            pixel[3] = cast(ubyte) ((color >>  0) & 0xFF);
        }

        OutBuffer payload = new OutBuffer;
        payload.reserve(image.width * image.height * 4 + image.height);
        for(int s = 0; s < image.height; s++) {
            payload.write(cast(ubyte) 0);
            for(int x = 0; x < image.width; x++) {
                getPixel(image.getRGB(x, s), pixel);
                payload.write(pixel);
            }
        }
        ubyte[] data = compress(payload.toBytes, 8);
        buf.write("IDAT");
        buf.write(data);
        writePacket(buf.toBytes, data.length, file);
        buf.clear;
    }

    private void writeIEND(ref File file) {
        ubyte[] data = [ 'I', 'E', 'N', 'D' ];
        writePacket(data, 0, file);
    }

    private void writeMagic(ref File file) {
        byte[] magic = cast(byte[]) [ 137, 80, 78, 71, 13, 10, 26, 10 ];
        file.rawWrite(magic);
    }

    /**
        Write image to file.
    */
    void writeImage(const Image image, ref File file) {
        writeMagic(file);
        writeIHDR(image, file);
        writeIDAT(image, file);
        writeIEND(file);
    }

}