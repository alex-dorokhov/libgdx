package com.badlogic.gdx.graphics.g2d;

import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Colors;
import com.badlogic.gdx.utils.GdxRuntimeException;
import com.badlogic.gdx.utils.StringBuilder;
import com.badlogic.gdx.utils.TextMarkdown;

/**
 * @see com.badlogic.gdx.graphics.g2d.BitmapFontCache
 *
 * @author davebaol
 */
public class ColorTagMarkdownParser {
    private final Color hexColor = new Color();
    private final StringBuilder colorBuffer = new StringBuilder();

    public ColorTagMarkdownParser() {
    }

    public int parseAndAddChunk(TextMarkdown markdown, CharSequence str, int nomarkdownStart, int start, int end) {
        if (start < end) {
            final Color hexColor = this.hexColor;
            if (str.charAt(start) == '#') {
                // Parse hex color RRGGBBAA where AA is optional and defaults to 0xFF if less than 6 chars are used
                int colorInt = 0;
                for (int i = start + 1; i < end; i++) {
                    char ch = str.charAt(i);
                    if (ch == ']') {
                        if (i < start + 2 || i > start + 9)
                            throw new GdxRuntimeException("Hex color cannot have " + (i - start - 1) + " digits.");
                        if (i <= start + 7) { // RRGGBB
                            Color.rgb888ToColor(hexColor, colorInt);
                            hexColor.a = 1f;
                        } else { // RRGGBBAA
                            Color.rgba8888ToColor(hexColor, colorInt);
                        }
                        markdown.addChunk(hexColor, nomarkdownStart);
                        return i - start;
                    }
                    if (ch >= '0' && ch <= '9')
                        colorInt = colorInt * 16 + (ch - '0');
                    else if (ch >= 'a' && ch <= 'f')
                        colorInt = colorInt * 16 + (ch - ('a' - 10));
                    else if (ch >= 'A' && ch <= 'F')
                        colorInt = colorInt * 16 + (ch - ('A' - 10));
                    else
                        throw new GdxRuntimeException("Unexpected character in hex color: " + ch);
                }
            } else {
                // Parse named color
                colorBuffer.setLength(0);
                for (int i = start; i < end; i++) {
                    char ch = str.charAt(i);
                    if (ch == ']') {
                        if (colorBuffer.length() == 0) { // end tag []
                            markdown.addChunk(null, nomarkdownStart);
                        } else {
                            String colorString = colorBuffer.toString();
                            Color newColor = Colors.get(colorString);
                            if (newColor == null) throw new GdxRuntimeException("Unknown color: " + colorString);
                            markdown.addChunk(newColor, nomarkdownStart);
                        }
                        return i - start;
                    } else {
                        colorBuffer.append(ch);
                    }
                }
            }
        }
        throw new GdxRuntimeException("Unclosed color tag.");
    }
}
