package com.badlogic.gdx.utils;

import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.g2d.BitmapFontCache;

/**
 * @see com.badlogic.gdx.graphics.g2d.BitmapFontCache
 *
 * @author davebaol
 * @author Alexander Dorokhov */
public class TextMarkdown {
    private static final Pool<ColorChunk> colorChunkPool = new Pool<ColorChunk>(32) {
        protected ColorChunk newObject () {
            return new ColorChunk();
        }
    };

    private Array<ColorChunk> colorChunks = new Array<ColorChunk>();
    private FloatArray colorStack = new FloatArray();
    private Color tempColor = new Color();

    public void addChunk(Color color, int start) {
        ColorChunk newChunk = colorChunkPool.obtain();
        newChunk.color = color;
        newChunk.start = start;
        addChunk(newChunk);
    }

    public void addChunk(ColorChunk newChunk) {
        // find place to insert
        final int size = colorChunks.size;
        int i;
        // usually it makes sense to start from the end
        for (i = size - 1; i >= 0; i--) {
            ColorChunk chunk = colorChunks.get(i);
            if (newChunk.start >= chunk.start) {
                i += 1;
                break;
            }
        }

        if (0 <= i && i < size) {
            colorChunks.insert(i, newChunk);
        } else {
            colorChunks.add(newChunk);
        }
    }

    public void tint(BitmapFontCache cache, Color tint, float floatTint) {
        int current = 0;
        float floatColor = floatTint;
        colorStack.clear();
        for (TextMarkdown.ColorChunk chunk : colorChunks) {
            int next = chunk.start;
            if (current < next) {
                cache.setColors(floatColor, current, next);
                current = next;
            }
            Color color = chunk.color;
            if (color != null) {
                colorStack.add(floatColor);
                floatColor = tempColor.set(color).mul(tint).toFloatBits();
            } else {
                if (colorStack.size > 0) {
                    floatColor = colorStack.pop();
                } else {
                    floatColor = floatTint;
                }
            }
        }
        int charsCount = cache.getCharsCount();
        if (current < charsCount) {
            cache.setColors(floatColor, current, charsCount);
        }
    }

    /** Removes all the color chunks from the list and releases them to the internal pool */
    public void clear() {
        for (ColorChunk chunk : colorChunks) {
            chunk.dispose();
        }
        colorChunks.clear();
    }

    public static class ColorChunk implements Disposable {
        public int start;
        public Color color;

        @Override
        public void dispose() {
            colorChunkPool.free(this);
        }
    }
}
