# Map58 Project Rules

## 1. MAP58 — MASTER GEOMETRY

These rules are absolute unless the user explicitly overrides them.

- **Map58 geometry / floorplan: JANGAN UBAH.**
- **Map58 position: JANGAN UBAH.**
- **Map58 collision: JANGAN UBAH.**
- Do not resize, rotate, translate, re-cut, rebuild, or reorganize Map58 geometry/collision.
- Do not modify Map58 merely to make another scene easier to place.
- Do not reset Map58 to an earlier state.

## 2. SCENE ANAK — LOCAL ONLY

For every child scene such as furniture, court, bleachers, props, characters, or other standalone scene:

- The scene root must use **local coordinates**.
- The child scene must **not contain or instance Map58**.
- The child scene must not depend on Map58 coordinates to define its own internal layout.
- Internal child objects are positioned relative to the child-scene root.
- The child-scene root stays at its local origin unless the user explicitly requests otherwise.
- World placement is controlled by the **parent scene / instance**.

## 3. INSTANCE / PARENT PLACEMENT

- The parent/instance decides where a child scene appears in the world.
- Do not move a child scene inside its own file merely to match a world placement.
- If a child scene needs to be moved in the map, change the **instance transform in the parent**, not the child scene's internal layout.
- Never silently change another scene's instance position.

## 4. NO UNREQUESTED CHANGES

- Do **not** change anything outside the exact task the user requested.
- Do not “clean up”, optimize, re-align, re-scale, re-parent, or redesign unrelated nodes.
- Do not restore older versions unless the user explicitly asks.
- Do not overwrite working geometry or placements while adding a new feature.
- One requested change = one focused modification.

## 5. WHEN ADDING ANYTHING

Before adding a new object/scene:

1. Inspect the actual current files and scene structure.
2. Identify the exact parent/instance that should receive the new object.
3. Keep the new object's internal coordinates local to its own scene.
4. Place it through the parent/instance transform when world placement is needed.
5. Preserve existing objects and their positions unless the user explicitly asks for a change.

After adding it, always explain the placement in concrete terms, including:
- what was added,
- which scene/node contains it,
- the parent/instance used,
- its local position,
- its world position when relevant,
- its orientation/rotation when relevant,
- and which existing objects were intentionally left unchanged.

## 6. INSPECTION BEFORE EDITING

Never guess the current state.

- Read the actual file before editing it.
- Check current transforms, parent paths, instances, and relevant dependencies.
- If the current file differs from an earlier remembered state, trust the **actual file**, not memory.
- Do not reset a scene just because the current version is inconvenient.

## 7. VALIDATION AFTER EDITING

Every structural/script/scene change must be validated before reporting completion.

- Verify the edited file exists and is syntactically valid.
- Verify the scene tree/parent paths remain valid.
- Verify no Map58 geometry, position, or collision was modified unless explicitly requested.
- Verify the intended instance placement.
- For scripts, check for parser/syntax errors.
- Report any uncertainty instead of claiming success.

## 8. GODOT PROJECT SAFETY

- Keep the project compatible with the current Godot version in use.
- Prefer editing the smallest possible set of files.
- Use the exact existing filename for replacements; do not create arbitrary V2/FIXED duplicates.
- Do not ask the user to repeat file replacement work when the project can be edited directly.
- Git is a safety net, not a reason to repeatedly reset working files.

## 9. CURRENT HARD CONSTRAINT

The following must remain true unless the user explicitly says otherwise:

**MAP58 GEOMETRY/FLOORPLAN = UNCHANGED**  
**MAP58 POSITION = UNCHANGED**  
**MAP58 COLLISION = UNCHANGED**  
**CHILD SCENE ROOTS = LOCAL**  
**CHILD SCENES = NO MAP58**  
**WORLD PLACEMENT = PARENT / INSTANCE**

## 10. COMMUNICATION RULE

Be direct and precise.

When making a change:
- state exactly what will change,
- state exactly where it will be placed,
- state what will not change,
- then validate the result.

If a requested change cannot be completed safely without violating these rules, say so before modifying files.

## 11. ASSISTANT ROLE — CARA KERJA

Peran asisten dalam project ini:

- Bertindak sebagai **developer/project maintainer**, bukan sekadar pemberi saran.
- Saat Remote Desktop Commander tersedia, kerjakan perubahan langsung di PC user.
- Selalu membaca kondisi file aktual sebelum mengubah sesuatu.
- Jangan mengandalkan ingatan percakapan lama jika file aktual menunjukkan keadaan berbeda.
- Jangan mengubah hal yang tidak diminta.
- Saat user mengatakan bentuk/posisi suatu objek sudah diubah manual, anggap kondisi tersebut sebagai **baseline baru** dan jangan mengembalikannya ke desain lama tanpa perintah.
- Untuk perubahan ukuran, pastikan membedakan **scale seragam** dengan **duplikasi/geometri tambahan**. Jangan mengubah satu sumbu saja bila tujuan user adalah memperbanyak keseluruhan bentuk.
- Bila user meminta "kalikan 2" pada suatu model/kelompok, pahami konteksnya dari struktur scene dan jangan langsung melakukan non-uniform scale yang dapat membuat objek gepeng.
- Bila ada ambiguitas teknis yang berpotensi merusak hasil, inspeksi struktur aktual terlebih dahulu; jangan menebak.
- Setelah perubahan, validasi file dan struktur scene sebelum menyatakan selesai.
- Jawaban kepada user harus langsung, singkat, dan menyebut perubahan konkret.
