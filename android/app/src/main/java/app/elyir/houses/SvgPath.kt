// SPDX-License-Identifier: Apache-2.0
/*
 The few SVG path commands the startup's marks use (M L H V C Z, absolute and relative), read as ios/Houses/SVGPath.swift
 reads them. Kept free of Android so the reading can be tested; StartupView turns it into a Path to draw.
 */
package app.elyir.houses

sealed interface Segment {
    data class Move(val x: Double, val y: Double) : Segment
    data class Line(val x: Double, val y: Double) : Segment
    data class Cubic(val x1: Double, val y1: Double, val x2: Double, val y2: Double, val x: Double, val y: Double) : Segment
    data object Close : Segment
}

data class Bounds(val x: Double, val y: Double, val width: Double, val height: Double)

object SvgPath {
    fun parse(d: String): List<Segment> {
        val path = mutableListOf<Segment>()
        val tokens = ArrayDeque(tokenize(d))
        var command = 'M'
        var atX = 0.0; var atY = 0.0
        var startX = 0.0; var startY = 0.0
        fun number(): Double = (tokens.firstOrNull() as? Token.Number)?.let { tokens.removeFirst(); it.value } ?: 0.0

        while (tokens.isNotEmpty()) {
            val token = tokens.first()
            if (token is Token.Command) { command = token.c; tokens.removeFirst() }
            val relative = command.isLowerCase()
            val bx = if (relative) atX else 0.0
            val by = if (relative) atY else 0.0
            when (command.uppercaseChar()) {
                'M' -> {
                    atX = bx + number(); atY = by + number()
                    path += Segment.Move(atX, atY); startX = atX; startY = atY
                    command = if (relative) 'l' else 'L'   // further pairs after a move are lines
                }
                'L' -> { atX = bx + number(); atY = by + number(); path += Segment.Line(atX, atY) }
                'H' -> { atX = (if (relative) atX else 0.0) + number(); path += Segment.Line(atX, atY) }
                'V' -> { atY = (if (relative) atY else 0.0) + number(); path += Segment.Line(atX, atY) }
                'C' -> {
                    val x1 = bx + number(); val y1 = by + number()
                    val x2 = bx + number(); val y2 = by + number()
                    atX = bx + number(); atY = by + number()
                    path += Segment.Cubic(x1, y1, x2, y2, atX, atY)
                }
                'Z' -> {
                    path += Segment.Close; atX = startX; atY = startY
                    if (tokens.firstOrNull() is Token.Number) tokens.removeFirst()
                }
                else -> tokens.removeFirst()
            }
        }
        return path
    }

    /** The box around every point of the path, control points included; exact for the house, which is all lines. */
    fun bounds(path: List<Segment>): Bounds {
        val xs = mutableListOf<Double>(); val ys = mutableListOf<Double>()
        for (s in path) when (s) {
            is Segment.Move -> { xs += s.x; ys += s.y }
            is Segment.Line -> { xs += s.x; ys += s.y }
            is Segment.Cubic -> { xs += listOf(s.x1, s.x2, s.x); ys += listOf(s.y1, s.y2, s.y) }
            Segment.Close -> {}
        }
        if (xs.isEmpty()) return Bounds(0.0, 0.0, 0.0, 0.0)
        return Bounds(xs.min(), ys.min(), xs.max() - xs.min(), ys.max() - ys.min())
    }

    private sealed interface Token {
        data class Command(val c: Char) : Token
        data class Number(val value: Double) : Token
    }

    private fun tokenize(d: String): List<Token> {
        val out = mutableListOf<Token>()
        var current = ""
        fun flush() { current.toDoubleOrNull()?.let { out += Token.Number(it) }; current = "" }
        for (ch in d) {
            when {
                ch.isLetter() && ch != 'e' -> { flush(); out += Token.Command(ch) }
                ch == '-' && current.isNotEmpty() && current.last() != 'e' -> { flush(); current = "-" }
                ch == ',' || ch.isWhitespace() -> flush()
                ch == '.' && current.contains('.') -> { flush(); current = "." }
                else -> current += ch
            }
        }
        flush()
        return out
    }
}
