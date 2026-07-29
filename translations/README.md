# GenyDL translations

English is the source language. The application currently ships Qt Linguist
catalogs for Persian (`fa_IR`), Arabic (`ar`), Turkish (`tr_TR`), German
(`de_DE`), French (`fr_FR`), Spanish (`es_ES`), Russian (`ru_RU`), and
Simplified Chinese (`zh_CN`).

Update catalogs after changing user-facing source text:

```sh
cmake --build <build-directory> --target GenyDL_lupdate
```

Review translations with Qt Linguist, then validate placeholders and compile
the catalogs:

```sh
node scripts/validate-translations.mjs
cmake --build <build-directory> --target GenyDL_lrelease
```

The generated `.qm` files are embedded under `/i18n`; they do not need a
platform-specific install step. Keep internal identifiers such as download
states, category IDs, and queue names in English and translate only their
display labels.
