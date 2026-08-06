import os

from conftest import MODULES

ROOT = os.path.dirname(os.path.abspath(__file__))

CATEGORIES = [
    ("unit", "check_unit_menu_banner", "unit"),
    ("component", "check_component_full_menu", "component"),
    (os.path.join("integration", "big_bang"), "check_integration_big_bang", "integration_big_bang"),
    (os.path.join("integration", "top_down"), "check_integration_top_down", "integration_top_down"),
    (os.path.join("integration", "bottom_up"), "check_integration_bottom_up", "integration_bottom_up"),
    (os.path.join("integration", "sandwich"), "check_integration_sandwich", "integration_sandwich"),
    ("system", "check_system_e2e", "system"),
    (os.path.join("acceptance", "uat"), "check_acceptance_uat", "acceptance_uat"),
    (os.path.join("acceptance", "alpha"), "check_acceptance_alpha", "acceptance_alpha"),
    (os.path.join("acceptance", "beta"), "check_acceptance_beta", "acceptance_beta"),
    (os.path.join("acceptance", "operational"), "check_acceptance_operational", "acceptance_operational"),
    (os.path.join("acceptance", "regulatory"), "check_acceptance_regulatory", "acceptance_regulatory"),
]

TEMPLATE = """import pytest


@pytest.mark.{marker}
def test_{prefix}_{modname}({fixture}):
    {fixture}("{MODULE}")
"""


def main():
    for rel_dir, fixture, marker in CATEGORIES:
        out_dir = os.path.join(ROOT, *rel_dir.split(os.sep))
        os.makedirs(out_dir, exist_ok=True)
        for module in MODULES:
            modname = module.lower()
            content = TEMPLATE.format(
                marker=marker,
                prefix=marker,
                modname=modname,
                fixture=fixture,
                MODULE=module,
            )
            path = os.path.join(out_dir, f"test_{modname}.py")
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
    total = len(CATEGORIES) * len(MODULES)
    print(f"Gerados {total} arquivos em {len(CATEGORIES)} categorias x {len(MODULES)} modulos")


if __name__ == "__main__":
    main()
