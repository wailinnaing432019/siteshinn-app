package com.siteshinn.site_shinn

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import io.flutter.FlutterInjector
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max

object NativePdfGenerator {
    private const val PAGE_WIDTH = 595
    private const val PAGE_HEIGHT = 842
    private const val MARGIN_H = 36f
    private const val MARGIN_TOP = 36f
    private const val MARGIN_BOTTOM = 44f
    private const val CONTENT_WIDTH = PAGE_WIDTH - (MARGIN_H * 2)

    private val primaryColor = Color.parseColor("#0F766E")
    private val lightBgColor = Color.parseColor("#F0FDFA")
    private val lightBorderColor = Color.parseColor("#99F6E4")
    private val evenRowColor = Color.parseColor("#F8FAFC")
    private val borderColor = Color.parseColor("#CBD5E1")
    private val textPrimaryColor = Color.parseColor("#0F172A")
    private val textMutedColor = Color.parseColor("#64748B")
    private val positiveGreenColor = Color.parseColor("#15803D")

    fun generateReportPdf(context: Context, payload: Map<String, Any?>) {
        val outputPath = payload["outputPath"] as? String
            ?: throw IllegalArgumentException("Missing outputPath")

        val brandTitle = payload["brandTitle"] as? String ?: "SiteShinn"
        val subtitle = payload["subtitle"] as? String ?: ""
        val summaryLabel = payload["summaryLabel"] as? String ?: ""
        val summaryValue = payload["summaryValue"] as? String ?: ""
        val footerText = payload["footerText"] as? String ?: "SiteShinn"
        @Suppress("UNCHECKED_CAST")
        val rawSections = payload["sections"] as? List<Map<String, Any?>> ?: emptyList()

        val regularTypeface = loadAssetTypeface(context, "assets/fonts/Pyidaungsu-Regular.ttf")
            ?: Typeface.DEFAULT
        val boldTypeface = loadAssetTypeface(context, "assets/fonts/Pyidaungsu-Bold.ttf")
            ?: Typeface.create(regularTypeface, Typeface.BOLD)

        val document = PdfDocument()
        try {
            var pageNumber = 1
            var page = document.startPage(
                PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, pageNumber).create()
            )
            var canvas = page.canvas
            var y = MARGIN_TOP

            fun finishCurrentPage() {
                drawFooter(canvas, footerText, pageNumber, regularTypeface)
                document.finishPage(page)
            }

            fun startNextPage() {
                finishCurrentPage()
                pageNumber += 1
                page = document.startPage(
                    PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, pageNumber).create()
                )
                canvas = page.canvas
                y = MARGIN_TOP
            }

            // 1. Header Banner
            y = drawBanner(
                canvas = canvas,
                y = y,
                brandTitle = brandTitle,
                subtitle = subtitle,
                summaryLabel = summaryLabel,
                summaryValue = summaryValue,
                regularTypeface = regularTypeface,
                boldTypeface = boldTypeface,
            )
            y += 16f

            // 2. Sections
            for (section in rawSections) {
                val sectionTitle = section["title"] as? String
                val emptyMessage = section["emptyMessage"] as? String
                @Suppress("UNCHECKED_CAST")
                val headers = (section["headers"] as? List<Any?>)?.map { it?.toString() ?: "" }
                    ?: emptyList()
                @Suppress("UNCHECKED_CAST")
                val alignments = (section["alignments"] as? List<Any?>)?.map { it?.toString() ?: "left" }
                    ?: emptyList()
                @Suppress("UNCHECKED_CAST")
                val weights = (section["weights"] as? List<Any?>)?.map {
                    (it as? Number)?.toFloat() ?: 1f
                } ?: List(headers.size) { 1f }
                @Suppress("UNCHECKED_CAST")
                val rows = (section["rows"] as? List<List<Any?>>)?.map { row ->
                    row.map { it?.toString() ?: "" }
                } ?: emptyList()

                if (sectionTitle != null && sectionTitle.isNotEmpty()) {
                    val titlePaint = makeTextPaint(boldTypeface, 12.5f, primaryColor)
                    val titleLayout = buildLayout(
                        sectionTitle,
                        titlePaint,
                        CONTENT_WIDTH.toInt(),
                        Layout.Alignment.ALIGN_NORMAL
                    )
                    if (y + titleLayout.height + 24f > PAGE_HEIGHT - MARGIN_BOTTOM) {
                        startNextPage()
                    }
                    canvas.save()
                    canvas.translate(MARGIN_H, y)
                    titleLayout.draw(canvas)
                    canvas.restore()
                    y += titleLayout.height + 6f
                }

                if (rows.isEmpty()) {
                    if (emptyMessage != null && emptyMessage.isNotEmpty()) {
                        val msgPaint = makeTextPaint(regularTypeface, 10f, textPrimaryColor)
                        val msgLayout = buildLayout(
                            emptyMessage,
                            msgPaint,
                            (CONTENT_WIDTH - 24f).toInt(),
                            Layout.Alignment.ALIGN_NORMAL
                        )
                        val boxHeight = msgLayout.height + 18f
                        if (y + boxHeight > PAGE_HEIGHT - MARGIN_BOTTOM) {
                            startNextPage()
                        }
                        val rect = RectF(MARGIN_H, y, MARGIN_H + CONTENT_WIDTH, y + boxHeight)
                        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = lightBgColor }
                        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                            color = lightBorderColor
                            style = Paint.Style.STROKE
                            strokeWidth = 0.8f
                        }
                        canvas.drawRoundRect(rect, 6f, 6f, bgPaint)
                        canvas.drawRoundRect(rect, 6f, 6f, strokePaint)
                        canvas.save()
                        canvas.translate(MARGIN_H + 12f, y + 9f)
                        msgLayout.draw(canvas)
                        canvas.restore()
                        y += boxHeight + 14f
                    }
                    continue
                }

                if (headers.isEmpty()) continue

                val totalWeight = weights.sum().let { if (it <= 0f) headers.size.toFloat() else it }
                val colWidths = weights.map { (it / totalWeight) * CONTENT_WIDTH }

                val headerTextPaint = makeTextPaint(boldTypeface, 9.5f, Color.WHITE)
                val bodyTextPaint = makeTextPaint(regularTypeface, 9.5f, textPrimaryColor)
                val paidTextPaint = makeTextPaint(boldTypeface, 9.5f, positiveGreenColor)
                val headerBgPaint = Paint().apply { color = primaryColor }
                val evenBgPaint = Paint().apply { color = evenRowColor }
                val whiteBgPaint = Paint().apply { color = Color.WHITE }
                val gridPaint = Paint().apply {
                    color = borderColor
                    style = Paint.Style.STROKE
                    strokeWidth = 0.6f
                }

                fun drawTableRow(
                    cells: List<String>,
                    isHeader: Boolean,
                    rowIndex: Int
                ): Boolean {
                    val padH = 6f
                    val padV = 5f
                    val layouts = cells.mapIndexed { idx, text ->
                        val colW = colWidths.getOrElse(idx) { 80f }
                        val innerW = max(12, (colW - (padH * 2)).toInt())
                        val align = when (alignments.getOrElse(idx) { "left" }) {
                            "right" -> Layout.Alignment.ALIGN_OPPOSITE
                            "center" -> Layout.Alignment.ALIGN_CENTER
                            else -> Layout.Alignment.ALIGN_NORMAL
                        }
                        val paint = when {
                            isHeader -> headerTextPaint
                            text == "Paid" || text == "ပေးပြီး" -> paidTextPaint
                            else -> bodyTextPaint
                        }
                        buildLayout(text, paint, innerW, align)
                    }
                    val rowHeight = (layouts.maxOfOrNull { it.height } ?: 14) + (padV * 2)

                    if (y + rowHeight > PAGE_HEIGHT - MARGIN_BOTTOM) {
                        return false
                    }

                    var x = MARGIN_H
                    for (idx in cells.indices) {
                        val colW = colWidths.getOrElse(idx) { 80f }
                        val cellRect = RectF(x, y, x + colW, y + rowHeight)
                        val bgPaint = when {
                            isHeader -> headerBgPaint
                            rowIndex % 2 == 1 -> evenBgPaint
                            else -> whiteBgPaint
                        }
                        canvas.drawRect(cellRect, bgPaint)
                        canvas.drawRect(cellRect, gridPaint)

                        val layout = layouts[idx]
                        val offsetY = y + ((rowHeight - layout.height) / 2f)
                        canvas.save()
                        canvas.translate(x + padH, offsetY)
                        layout.draw(canvas)
                        canvas.restore()

                        x += colW
                    }
                    y += rowHeight
                    return true
                }

                // Draw table header
                if (!drawTableRow(headers, isHeader = true, rowIndex = 0)) {
                    startNextPage()
                    drawTableRow(headers, isHeader = true, rowIndex = 0)
                }

                for (rIdx in rows.indices) {
                    val row = rows[rIdx]
                    if (!drawTableRow(row, isHeader = false, rowIndex = rIdx)) {
                        startNextPage()
                        drawTableRow(headers, isHeader = true, rowIndex = 0)
                        drawTableRow(row, isHeader = false, rowIndex = rIdx)
                    }
                }
                y += 14f
            }

            finishCurrentPage()

            val outFile = File(outputPath)
            outFile.parentFile?.mkdirs()
            FileOutputStream(outFile).use { fos ->
                document.writeTo(fos)
            }
        } finally {
            document.close()
        }
    }

    private fun drawBanner(
        canvas: Canvas,
        y: Float,
        brandTitle: String,
        subtitle: String,
        summaryLabel: String,
        summaryValue: String,
        regularTypeface: Typeface,
        boldTypeface: Typeface,
    ): Float {
        val padH = 16f
        val padV = 14f
        val rightColW = 165f
        val leftColW = CONTENT_WIDTH - (padH * 2) - rightColW - 12f

        val titlePaint = makeTextPaint(boldTypeface, 15.5f, Color.WHITE)
        val subPaint = makeTextPaint(regularTypeface, 10f, Color.WHITE)
        val sumLabelPaint = makeTextPaint(regularTypeface, 9.5f, Color.WHITE)
        val sumValPaint = makeTextPaint(boldTypeface, 14.5f, Color.WHITE)

        val titleLayout = buildLayout(brandTitle, titlePaint, leftColW.toInt(), Layout.Alignment.ALIGN_NORMAL)
        val subLayout = buildLayout(subtitle, subPaint, leftColW.toInt(), Layout.Alignment.ALIGN_NORMAL)
        val sumLabelLayout = buildLayout(summaryLabel, sumLabelPaint, rightColW.toInt(), Layout.Alignment.ALIGN_OPPOSITE)
        val sumValLayout = buildLayout(summaryValue, sumValPaint, rightColW.toInt(), Layout.Alignment.ALIGN_OPPOSITE)

        val leftH = titleLayout.height + 4f + subLayout.height
        val rightH = sumLabelLayout.height + 2f + sumValLayout.height
        val boxHeight = max(leftH, rightH) + (padV * 2)

        val rect = RectF(MARGIN_H, y, MARGIN_H + CONTENT_WIDTH, y + boxHeight)
        val bannerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = primaryColor }
        canvas.drawRoundRect(rect, 8f, 8f, bannerPaint)

        canvas.save()
        canvas.translate(MARGIN_H + padH, y + padV)
        titleLayout.draw(canvas)
        canvas.translate(0f, titleLayout.height + 4f)
        subLayout.draw(canvas)
        canvas.restore()

        val rightX = MARGIN_H + CONTENT_WIDTH - padH - rightColW
        canvas.save()
        canvas.translate(rightX, y + padV)
        sumLabelLayout.draw(canvas)
        canvas.translate(0f, sumLabelLayout.height + 2f)
        sumValLayout.draw(canvas)
        canvas.restore()

        return y + boxHeight
    }

    private fun drawFooter(
        canvas: Canvas,
        footerText: String,
        pageNumber: Int,
        regularTypeface: Typeface,
    ) {
        val footerPaint = makeTextPaint(regularTypeface, 8.5f, textMutedColor)
        val layout = buildLayout(
            "$footerText • Page $pageNumber",
            footerPaint,
            CONTENT_WIDTH.toInt(),
            Layout.Alignment.ALIGN_OPPOSITE
        )
        canvas.save()
        canvas.translate(MARGIN_H, PAGE_HEIGHT - 28f)
        layout.draw(canvas)
        canvas.restore()
    }

    private fun makeTextPaint(typeface: Typeface, sizeSp: Float, color: Int): TextPaint {
        return TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.typeface = typeface
            this.textSize = sizeSp
            this.color = color
        }
    }

    private fun buildLayout(
        text: String,
        paint: TextPaint,
        width: Int,
        alignment: Layout.Alignment,
    ): StaticLayout {
        val safeW = max(10, width)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            StaticLayout.Builder.obtain(text, 0, text.length, paint, safeW)
                .setAlignment(alignment)
                .setLineSpacing(0f, 1.15f)
                .setIncludePad(false)
                .build()
        } else {
            @Suppress("DEPRECATION")
            StaticLayout(text, paint, safeW, alignment, 1.15f, 0f, false)
        }
    }

    private fun loadAssetTypeface(context: Context, assetPath: String): Typeface? {
        return try {
            val lookupKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
            Typeface.createFromAsset(context.assets, lookupKey)
        } catch (_: Exception) {
            null
        }
    }
}
