// Do not edit this file! Generated by Ragel.
// Ragel.exe -G2 -J -o XmlReader.java XmlReader.rl
/*******************************************************************************
 * Copyright 2011 See AUTHORS file.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 ******************************************************************************/

package com.badlogic.gdx.utils;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;

import com.badlogic.gdx.files.FileHandle;
import com.badlogic.gdx.utils.ObjectMap.Entry;

/** Lightweight XML parser. Supports a subset of XML features: elements, attributes, text, predefined entities, CDATA, mixed
 * content. Namespaces are parsed as part of the element or attribute name. Prologs and doctypes are ignored. Only 8-bit character
 * encodings are supported. Input is assumed to be well formed.<br>
 * <br>
 * The default behavior is to parse the XML into a DOM. Extends this class and override methods to perform event driven parsing.
 * When this is done, the parse methods will return null.
 * @author Nathan Sweet */
public class XmlReader {
	private final Array<Element> elements = new Array(8);
	private Element root, current;
	private final StringBuilder textBuffer = new StringBuilder(64);

	public Element parse (String xml) {
		char[] data = xml.toCharArray();
		return parse(data, 0, data.length);
	}

	public Element parse (Reader reader) throws IOException {
		char[] data = new char[1024];
		int offset = 0;
		while (true) {
			int length = reader.read(data, offset, data.length - offset);
			if (length == -1) break;
			if (length == 0) {
				char[] newData = new char[data.length * 2];
				System.arraycopy(data, 0, newData, 0, data.length);
				data = newData;
			} else
				offset += length;
		}
		return parse(data, 0, offset);
	}

	public Element parse (InputStream input) throws IOException {
		return parse(new InputStreamReader(input, "ISO-8859-1"));
	}

	public Element parse (FileHandle file) throws IOException {
		return parse(file.read());
	}

	public Element parse (char[] data, int offset, int length) {
		int cs, p = offset, pe = length;

		int s = 0;
		String attributeName = null;
		boolean hasBody = false;

		%%{
		machine xml;

		action buffer { s = p; }
		action elementStart {
			char c = data[s];
			if (c == '?' || c == '!') {
				if (
					data[s + 1] == '[' && //
					data[s + 2] == 'C' && //
					data[s + 3] == 'D' && //
					data[s + 4] == 'A' && //
					data[s + 5] == 'T' && //
					data[s + 6] == 'A' && //
					data[s + 7] == '['
				) {
					s += 8;
					p = s + 2;
					while (data[p - 2] != ']' || data[p - 1] != ']' || data[p] != '>')
						p++;
					text(new String(data, s, p - s - 2));
				} else
					while (data[p] != '>') p++;
				fgoto elementBody;
			}
			hasBody = true;
			open(new String(data, s, p - s));
		}
		action elementEndSingle {
			hasBody = false;
			close();
			fgoto elementBody;
		}
		action elementEnd {
			close();
			fgoto elementBody;
		}
		action element {
			if (hasBody) fgoto elementBody;
		}
		action attributeName {
			attributeName = new String(data, s, p - s);
		}
		action attribute {
			attribute(attributeName, new String(data, s, p - s));
		}
		action text {
			int end = p;
			while (end != s) {
				switch (data[end - 1]) {
				case ' ':
				case '\t':
				case '\n':
				case '\r':
					end--;
					continue;
				}
				break;
			}
			int current = s;
			boolean entityFound = false;
			while (current != end) {
				if (data[current++] != '&') continue;
				int entityStart = current;
				while (current != end) {
					if (data[current++] != ';') continue;
					textBuffer.append(data, s, entityStart - s - 1);
					String name = new String(data, entityStart, current - entityStart - 1);
					String value = entity(name);
					textBuffer.append(value != null ? value : name);
					s = current;
					entityFound = true;
					break;
				}
			}
			if (entityFound) {
				if (s < end) textBuffer.append(data, s, end - s);
				text(textBuffer.toString());
				textBuffer.setLength(0);
			} else
				text(new String(data, s, end - s));
		}

		attribute = ^(space | [/>=])+ >buffer %attributeName space* '=' space*
			(('\'' ^'\''* >buffer %attribute '\'') | ('"' ^'"'* >buffer %attribute '"'));
		element = '<' space* ^(space | [/>])+ >buffer %elementStart (space+ attribute)*
			:>> (space* ('/' %elementEndSingle)? space* '>' @element);
		elementBody := space* <: ((^'<'+ >buffer %text) <: space*)?
			element? :>> ('<' space* '/' ^'>'+ '>' @elementEnd);
		main := space* element space*;

		write init;
		write exec;
		}%%

		if (p < pe) {
			int lineNumber = 1;
			for (int i = 0; i < p; i++)
				if (data[i] == '\n') lineNumber++;
			throw new IllegalArgumentException("Error parsing XML on line " + lineNumber + " near: "
				+ new String(data, p, Math.min(32, pe - p)));
		} else if (elements.size != 0) {
			Element element = elements.peek();
			elements.clear();
			throw new IllegalArgumentException("Error parsing XML, unclosed element: " + element.getName());
		}
		Element root = this.root;
		this.root = null;
		return root;
	}

	%% write data;

	protected void open (String name) {
		Element child = new Element(name, current);
		Element parent = current;
		if (parent != null) parent.addChild(child);
		elements.add(child);
		current = child;
	}

	protected void attribute (String name, String value) {
		current.setAttribute(name, value);
	}

	protected String entity (String name) {
		if (name.equals("lt")) return "<";
		if (name.equals("gt")) return ">";
		if (name.equals("amp")) return "&";
		if (name.equals("apos")) return "'";
		if (name.equals("quot")) return "\"";
		return null;
	}

	protected void text (String text) {
		String existing = current.getText();
		current.setText(existing != null ? existing + text : text);
	}

	protected void close () {
		root = elements.pop();
		current = elements.size > 0 ? elements.peek() : null;
	}

	static public class Element {
		private final String name;
		private ObjectMap<String, String> attributes;
		private Array<Element> children;
		private String text;
		private Element parent;

		public Element (String name, Element parent) {
			this.name = name;
			this.parent = parent;
		}

		public String getName () {
			return name;
		}

		/** @throws GdxRuntimeException if the attribute was not found. */
		public String getAttribute (String name) {
			if (attributes == null) throw new GdxRuntimeException("Element " + name + " doesn't have attribute: " + name);
			String value = attributes.get(name);
			if (value == null) throw new GdxRuntimeException("Element " + name + " doesn't have attribute: " + name);
			return value;
		}

		public String getAttribute (String name, String defaultValue) {
			if (attributes == null) return defaultValue;
			String value = attributes.get(name);
			if (value == null) return defaultValue;
			return value;
		}

		public void setAttribute (String name, String value) {
			if (attributes == null) attributes = new ObjectMap(8);
			attributes.put(name, value);
		}

		public int getChildCount () {
			if (children == null) return 0;
			return children.size;
		}

		/** @throws GdxRuntimeException if the element has no children. */
		public Element getChild (int i) {
			if (children == null) throw new GdxRuntimeException("Element has no children: " + name);
			return children.get(i);
		}

		public void addChild (Element element) {
			if (children == null) children = new Array(8);
			children.add(element);
		}

		public String getText () {
			return text;
		}

		public void setText (String text) {
			this.text = text;
		}

		public void removeChild (int index) {
			if (children != null) children.removeIndex(index);
		}

		public void removeChild (Element child) {
			if (children != null) children.removeValue(child, true);
		}

		public void remove () {
			parent.removeChild(this);
		}

		public Element getParent () {
			return parent;
		}

		public String toString () {
			return toString("");
		}

		public String toString (String indent) {
			StringBuilder buffer = new StringBuilder(128);
			buffer.append(indent);
			buffer.append('<');
			buffer.append(name);
			if (attributes != null) {
				for (Entry<String, String> entry : attributes.entries()) {
					buffer.append(' ');
					buffer.append(entry.key);
					buffer.append("=\"");
					buffer.append(entry.value);
					buffer.append('\"');
				}
			}
			if (children == null && (text == null || text.length() == 0))
				buffer.append("/>");
			else {
				buffer.append(">\n");
				String childIndent = indent + '\t';
				if (text != null && text.length() > 0) {
					buffer.append(childIndent);
					buffer.append(text);
					buffer.append('\n');
				}
				if (children != null) {
					for (Element child : children) {
						buffer.append(child.toString(childIndent));
						buffer.append('\n');
					}
				}
				buffer.append(indent);
				buffer.append("</");
				buffer.append(name);
				buffer.append('>');
			}
			return buffer.toString();
		}

		/** @param name the name of the child {@link Element}
		 * @return the first child having the given name or null, does not recurse */
		public Element getChildByName (String name) {
			if (children == null) return null;
			for (int i = 0; i < children.size; i++) {
				Element element = children.get(i);
				if (element.name.equals(name)) return element;
			}
			return null;
		}

		/** @param name the name of the child {@link Element}
		 * @return the first child having the given name or null, recurses */
		public Element getChildByNameRecursive (String name) {
			if (children == null) return null;
			for (int i = 0; i < children.size; i++) {
				Element element = children.get(i);
				if (element.name.equals(name)) return element;
				Element found = element.getChildByNameRecursive(name);
				if (found != null) return found;
			}
			return null;
		}

		/** @param name the name of the children
		 * @return the children with the given name or an empty {@link Array} */
		public Array<Element> getChildrenByName (String name) {
			Array<Element> result = new Array<Element>();
			if (children == null) return result;
			for (int i = 0; i < children.size; i++) {
				Element child = children.get(i);
				if (child.name.equals(name)) result.add(child);
			}
			return result;
		}

		/** @param name the name of the children
		 * @return the children with the given name or an empty {@link Array} */
		public Array<Element> getChildrenByNameRecursively (String name) {
			Array<Element> result = new Array<Element>();
			getChildrenByNameRecursively(name, result);
			return result;
		}

		private void getChildrenByNameRecursively (String name, Array<Element> result) {
			if (children == null) return;
			for (int i = 0; i < children.size; i++) {
				Element child = children.get(i);
				if (child.name.equals(name)) result.add(child);
				child.getChildrenByNameRecursively(name, result);
			}
		}

		/** @throws GdxRuntimeException if the attribute was not found. */
		public float getFloatAttribute (String name) {
			return Float.parseFloat(getAttribute(name));
		}

		public float getFloatAttribute (String name, float defaultValue) {
			String value = getAttribute(name, null);
			if (value == null) return defaultValue;
			return Float.parseFloat(value);
		}

		/** @throws GdxRuntimeException if the attribute was not found. */
		public int getIntAttribute (String name) {
			return Integer.parseInt(getAttribute(name));
		}

		public int getIntAttribute (String name, int defaultValue) {
			String value = getAttribute(name, null);
			if (value == null) return defaultValue;
			return Integer.parseInt(value);
		}

		/** @throws GdxRuntimeException if the attribute was not found. */
		public boolean getBooleanAttribute (String name) {
			return Boolean.parseBoolean(getAttribute(name));
		}

		public boolean getBooleanAttribute (String name, boolean defaultValue) {
			String value = getAttribute(name, null);
			if (value == null) return defaultValue;
			return Boolean.parseBoolean(value);
		}

		/** Returns the attribute value with the specified name, or if no attribute is found, the text of a child with the name.
		 * @throws GdxRuntimeException if no attribute or child was not found. */
		public String get (String name) {
			String value = get(name, null);
			if (value == null) throw new GdxRuntimeException("Element " + this.name + " doesn't have attribute or child: " + name);
			return value;
		}

		/** Returns the attribute value with the specified name, or if no attribute is found, the text of a child with the name.
		 * @throws GdxRuntimeException if no attribute or child was not found. */
		public String get (String name, String defaultValue) {
			if (attributes != null) {
				String value = attributes.get(name);
				if (value != null) return value;
			}
			Element child = getChildByName(name);
			if (child == null) return defaultValue;
			String value = child.getText();
			if (value == null) return defaultValue;
			return value;
		}

		/** Returns the attribute value with the specified name, or if no attribute is found, the text of a child with the name.
		 * @throws GdxRuntimeException if no attribute or child was not found. */
		public int getInt (String name) {
			String value = get(name, null);
			if (value == null) throw new GdxRuntimeException("Element " + this.name + " doesn't have attribute or child: " + name);
			return Integer.parseInt(value);
		}

		/** Returns the attribute value with the specified name, or if no attribute is found, the text of a child with the name.
		 * @throws GdxRuntimeException if no attribute or child was not found. */
		public int getInt (String name, int defaultValue) {
			String value = get(name, null);
			if (value == null) return defaultValue;
			return Integer.parseInt(value);
		}

		/** Returns the attribute value with the specified name, or if no attribute is found, the text of a child with the name.
		 * @throws GdxRuntimeException if no attribute or child was not found. */
		public float getFloat (String name) {
			String value = get(name, null);
			if (value == null) throw new GdxRuntimeException("Element " + this.name + " doesn't have attribute or child: " + name);
			return Float.parseFloat(value);
		}

		/** Returns the attribute value with the specified name, or if no attribute is found, the text of a child with the name.
		 * @throws GdxRuntimeException if no attribute or child was not found. */
		public float getFloat (String name, float defaultValue) {
			String value = get(name, null);
			if (value == null) return defaultValue;
			return Float.parseFloat(value);
		}

		/** Returns the attribute value with the specified name, or if no attribute is found, the text of a child with the name.
		 * @throws GdxRuntimeException if no attribute or child was not found. */
		public boolean getBoolean (String name) {
			String value = get(name, null);
			if (value == null) throw new GdxRuntimeException("Element " + this.name + " doesn't have attribute or child: " + name);
			return Boolean.parseBoolean(value);
		}

		/** Returns the attribute value with the specified name, or if no attribute is found, the text of a child with the name.
		 * @throws GdxRuntimeException if no attribute or child was not found. */
		public boolean getBoolean (String name, boolean defaultValue) {
			String value = get(name, null);
			if (value == null) return defaultValue;
			return Boolean.parseBoolean(value);
		}
	}
}
