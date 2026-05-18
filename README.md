# ⭐ Starpath RPG

> RPG por turnos desarrollado en **Godot 4** con estética pixel art, exploración de mundo, sistema de combate estratégico y narrativa.

![Godot](https://img.shields.io/badge/Godot-4.x-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-language-blue?style=for-the-badge)
![License](https://img.shields.io/badge/Licencia-MIT-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Estado-En%20desarrollo-yellow?style=for-the-badge)

---

## 🎮 Descripción

**Starpath RPG** es un videojuego de rol por turnos en 2D desarrollado como Trabajo de Fin de Grado del ciclo formativo de **Desarrollo de Aplicaciones Multiplataforma (DAM)**. El jugador explora un mundo de pixel art, interactúa con NPCs, compra objetos en tiendas y se enfrenta a enemigos en combates por turnos estratégicos.

El proyecto incluye además una **página web promocional** desarrollada en Angular 19: [web-starpath.vercel.app](https://web-starpath.vercel.app)

---

## ✨ Características principales

- ⚔️ **Sistema de combate por turnos** con acciones de ataque, habilidades, objetos y huida
- 🧠 **IA enemiga** con probabilidad de usar habilidades especiales
- 🧪 **Sistema de inventario** con objetos consumibles (pociones, éter, etc.)
- 🛒 **Tienda con NPCs** — compra y venta de objetos
- 💬 **Sistema de diálogos** con NPCs interactivos
- 🗺️ **Exploración de mundo** con enemigos que patrullan el mapa
- 🏃 **Mecánica de huida** — al escapar, el enemigo queda paralizado unos segundos
- 💾 **Sistema de guardado/carga** mediante JSON
- 🎵 **Gestor de audio** con música y efectos de sonido
- ⚙️ **Menú de opciones** con rebinding de teclas y ajuste de volumen
- 🎯 **Modo automático de combate** para acelerar los turnos
- 🖥️ **Transiciones de escena** animadas

---

## 🧩 Personajes y enemigos

### Personajes jugables
| Nombre | Clase | Especialidad |
|--------|-------|--------------|
| Byran | Guerrero | Daño físico y defensa |
| Lyra | Maga | Daño mágico a distancia |
| Athelios | Pícaro | Críticos y sigilo |

### Enemigos
| Nombre | HP | Habilidad especial |
|--------|----|--------------------|
| Limo | 60 | Mordisco |
| Limo Jefe | 80 | Maldición |
| Calabaza | 65 | Explosión |
| Goblin | 45 | Emboscada |

---

## 🛠️ Tecnologías

| Tecnología | Uso |
|------------|-----|
| **Godot 4** | Motor de desarrollo |
| **GDScript** | Lenguaje de programación |
| **JSON** | Sistema de guardado |
| **Angular 19** | Web promocional |
| **Supabase** | Autenticación web |
| **Vercel** | Despliegue web |

---

## 📁 Estructura del proyecto

```
game-starpath/
└── starpath/
    ├── Assets/          # Sprites, tilesets, audio, fuentes
    ├── Autoloads/       # Singletons globales (Inventory, SaveManager, AudioManager...)
    ├── Resources/       # Datos (.tres) de personajes, enemigos y habilidades
    ├── Scenes/          # Escenas del juego (Battle, World, UI)
    └── Scripts/         # Lógica de juego (combate, mundo, UI)
```

### Autoloads (Singletons)
- `Inventory` — Gestión de inventario y estado de partida
- `SaveManager` — Guardado y carga de partida en JSON
- `AudioManager` — Control de música y efectos de sonido
- `DialogManager` — Sistema de diálogos con NPCs
- `ShopManager` — Sistema de tienda y compraventa
- `SceneTransition` — Transiciones animadas entre escenas
- `SettingsManager` — Opciones y configuración del jugador
- `TutorialManager` — Sistema de tutorial inicial

---

## 🚀 Cómo ejecutar el proyecto

### Requisitos
- [Godot 4.x](https://godotengine.org/download/) instalado

### Pasos
1. Clona el repositorio:
   ```bash
   git clone https://github.com/Ataik7/starpath.git
   ```
2. Abre **Godot 4** y selecciona **Import Project**
3. Navega hasta la carpeta `starpath/` y abre el archivo `project.godot`
4. Pulsa **Play** (F5) para ejecutar

---

## 👥 Autores

| Nombre | Rol |
|--------|-----|
| **Pablo Nicolás Gallego Delgado** | Desarrollo |
| **Iván Gastineau** | Desarrollo |

Proyecto desarrollado en el **IES El Cañaveral** — Ciclo Formativo de Grado Superior en Desarrollo de Aplicaciones Multiplataforma (DAM).

---

## 🌐 Web promocional

La página web del juego está disponible en:
**[https://web-starpath.vercel.app](https://web-starpath.vercel.app)**

Desarrollada con Angular 19 + Supabase + Vercel.

---

## 📄 Licencia

Este proyecto está bajo la licencia **MIT**. Consulta el archivo `LICENSE` para más detalles.
