#!/usr/bin/env python3
"""Arregla los .dae de The Models Resource para el importador Collada de Godot.

Los interiores de B2W2 ponen varias <instance_geometry> en un mismo <node>; Godot solo
importa una por nodo ("Multiple instance_* not supported") y el resto se pierde. Este
script mueve cada instancia extra a un <node> hijo nuevo (misma posición: los hijos no
tienen transformación propia). Modifica los archivos en su lugar (idempotente).

Uso: python3 tools/fix_dae.py art/models/b2w2_int
"""
import sys
import urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path

NS = "http://www.collada.org/2005/11/COLLADASchema"
ET.register_namespace("", NS)
INSTANCES = ("instance_geometry", "instance_controller")


def fix(path: Path) -> int:
    tree = ET.parse(path)
    moved = 0
    for node in tree.iter(f"{{{NS}}}node"):
        instances = [c for c in list(node) if c.tag.split("}")[1] in INSTANCES]
        if len(instances) <= 1:
            continue
        for index, inst in enumerate(instances[1:], start=1):
            node.remove(inst)
            child = ET.SubElement(node, f"{{{NS}}}node", {"id": f"{node.get('id', 'n')}_part{index}", "name": f"{node.get('name', 'n')}_part{index}", "type": "NODE"})
            child.append(inst)
            moved += 1
    # Texturas: las rutas vienen codificadas ("Pok%c3%a9mon%20Center_texture_0001.png") y
    # Godot no las decodifica; se renombran a "t_0001.png" y se actualiza la referencia.
    renamed = 0
    for init in tree.iter(f"{{{NS}}}init_from"):
        if not init.text or not init.text.lower().endswith(".png"):
            continue
        original = urllib.parse.unquote(init.text)
        source = path.parent / original
        safe = "t_" + original.rsplit("_", 1)[-1] if "_" in original else original
        target = path.parent / safe
        if source.exists() and source != target:
            source.rename(target)
            old_import = path.parent / (original + ".import")
            if old_import.exists():
                old_import.unlink()
        if target.exists() and init.text != safe:
            init.text = safe
            renamed += 1
    if moved or renamed:
        tree.write(path, xml_declaration=True, encoding="utf-8")
    # El .dae también con nombre simple.
    if path.name != "model.dae":
        (path.parent / (path.name + ".import")).unlink(missing_ok=True)
        path.rename(path.parent / "model.dae")
    return moved


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "art/models/b2w2_int")
    total = 0
    for dae in root.rglob("*.dae"):
        moved = fix(dae)
        total += moved
        print(f"{dae.parent.name}: {moved} instancias separadas")
    print(f"Total: {total}")


if __name__ == "__main__":
    main()
