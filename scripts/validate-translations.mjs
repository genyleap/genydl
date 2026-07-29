#!/usr/bin/env node

import fs from "node:fs"
import path from "node:path"

const repositoryRoot = path.resolve(import.meta.dirname, "..")
const requested = process.argv.slice(2)
const files = requested.length > 0
    ? requested.map(code => path.join(repositoryRoot, "translations", `genydl_${code}.ts`))
    : fs.readdirSync(path.join(repositoryRoot, "translations"))
        .filter(name => name.endsWith(".ts"))
        .map(name => path.join(repositoryRoot, "translations", name))

function decodeXml(value) {
    return value
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&quot;", '"')
        .replaceAll("&apos;", "'")
        .replaceAll("&amp;", "&")
}

function placeholders(value) {
    return [...value.matchAll(/%(?:L?\d+|Ln|n)/g)]
        .map(match => match[0])
        .sort()
        .join("|")
}

let failed = false
for (const file of files) {
    const xml = fs.readFileSync(file, "utf8")
    const messages = [...xml.matchAll(/<message(?:\s+numerus="yes")?>([\s\S]*?)<\/message>/g)]
    const errors = []

    if (xml.includes('type="unfinished"'))
        errors.push("contains unfinished translations")

    for (const [index, match] of messages.entries()) {
        const isNumerus = match[0].startsWith('<message numerus="yes">')
        const source = decodeXml(match[1].match(/<source>([\s\S]*?)<\/source>/)?.[1] ?? "")
        const translationBlock = match[1].match(/<translation[^>]*>([\s\S]*?)<\/translation>/)?.[1] ?? ""
        const forms = [...translationBlock.matchAll(/<numerusform>([\s\S]*?)<\/numerusform>/g)]
        const translations = forms.length > 0
            ? forms.map(form => decodeXml(form[1]))
            : [decodeXml(translationBlock)]

        for (const translation of translations) {
            if (!translation.trim())
                errors.push(`message ${index + 1} has an empty translation`)
            // Qt numerus translations may legitimately spell out one/two and
            // omit %n (notably Arabic). Positional placeholders must still
            // match exactly in every form.
            const sourcePlaceholders = isNumerus
                ? placeholders(source).split("|").filter(value => value !== "%n").join("|")
                : placeholders(source)
            const translationPlaceholders = isNumerus
                ? placeholders(translation).split("|").filter(value => value !== "%n").join("|")
                : placeholders(translation)
            if (sourcePlaceholders !== translationPlaceholders)
                errors.push(`message ${index + 1} placeholder mismatch: ${JSON.stringify(source)}`)
        }
    }

    if (path.basename(file) === "genydl_fa.ts") {
        const requiredPersianGlossary = new Map([
            ["State", "وضعیت"],
            ["Status", "وضعیت"],
            ["URL", "نشانی اینترنتی"],
            ["ETA", "زمان باقی‌مانده"],
            ["macOS", "مک‌او‌اس"],
            ["NFT", "توکن غیرمثلی"],
            ["NFTs", "توکن‌های غیرمثلی"],
            ["GenyDL", "نرم‌افزار جنی‌دی‌اِل"],
            ["Options", "تنظیمات"],
            ["Schedule", "برنامه‌ریزی"],
            ["Share", "اشتراک‌گذاری"],
            ["B", "بایت"],
            ["KB", "کیلوبایت"],
            ["MB", "مگابایت"],
            ["GB", "گیگابایت"],
            ["TB", "ترابایت"],
            ["%", "٪"],
            ["%1/s", "%1 بر ثانیه"],
        ])
        const actual = new Map()
        for (const match of messages) {
            const source = decodeXml(match[1].match(/<source>([\s\S]*?)<\/source>/)?.[1] ?? "")
            const translation = decodeXml(
                match[1].match(/<translation[^>]*>([\s\S]*?)<\/translation>/)?.[1] ?? "")
            actual.set(source, translation.replace(/<\/?numerusform>/g, "").trim())
        }
        for (const [source, expected] of requiredPersianGlossary) {
            if (actual.get(source) !== expected)
                errors.push(`Persian glossary mismatch for ${JSON.stringify(source)}: expected ${JSON.stringify(expected)}`)
        }

        const forbiddenPersianForms = [
            "ایالت",
            "برنامه ریزی",
            "به روز رسانی",
            "گزینه ها",
            "صف ها",
            "NFT ها",
        ]
        for (const form of forbiddenPersianForms) {
            if (xml.includes(form))
                errors.push(`contains non-standard Persian form: ${JSON.stringify(form)}`)
        }
        if (/[يك]/u.test(xml))
            errors.push("contains Arabic ي/ك instead of Persian ی/ک")
    }

    const label = path.basename(file)
    if (errors.length > 0) {
        failed = true
        process.stderr.write(`${label}: ${errors.length} error(s)\n${errors.map(error => `  - ${error}`).join("\n")}\n`)
    } else {
        process.stdout.write(`${label}: ${messages.length} complete messages, placeholders valid\n`)
    }
}

if (failed)
    process.exitCode = 1
