import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {QuickMenuToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';

Gio._promisify(Gio.Subprocess.prototype, 'communicate_utf8_async');

const BIN = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin']);
const ICONO_JUEGO = 'input-gaming-symbolic';
const ICONO_IA = 'applications-science-symbolic';
const REFRESCO_SEG = 30;
// Steam escribe el avance en shader_log.txt cada 10 s.
const REFRESCO_SHADERS_SEG = 10;

async function ejecutar(argv) {
    try {
        const proc = Gio.Subprocess.new(argv,
            Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE);
        const [stdout] = await proc.communicate_utf8_async(null, null);
        return [proc.get_successful(), (stdout ?? '').trim()];
    } catch (e) {
        return [false, e.message];
    }
}

// Fila de menu con texto y barra de avance. Con alActivar es clicable y no cierra el menu.
const FilaProgreso = GObject.registerClass(
class FilaProgreso extends PopupMenu.PopupBaseMenuItem {
    _init(alActivar = null, sangria = false) {
        super._init({reactive: alActivar !== null});
        this._alActivar = alActivar;
        this._fraccion = 0;

        const caja = new St.BoxLayout({
            orientation: Clutter.Orientation.VERTICAL,
            x_expand: true,
            style: `spacing: 6px;${sangria ? ' padding-left: 16px;' : ''}`,
        });
        const cabecera = new St.BoxLayout({x_expand: true});
        this._label = new St.Label({x_expand: true, y_align: Clutter.ActorAlign.CENTER});
        this._flecha = new St.Icon({style_class: 'popup-menu-arrow', visible: false});
        cabecera.add_child(this._label);
        cabecera.add_child(this._flecha);

        this._barra = new St.Widget({
            layout_manager: new Clutter.BinLayout(),
            x_expand: true,
            visible: false,
            style: 'height: 6px; border-radius: 3px; background-color: rgba(255,255,255,0.15);',
        });
        this._relleno = new St.Widget({
            x_align: Clutter.ActorAlign.START,
            style: 'border-radius: 3px; background-color: -st-accent-color;',
        });
        this._barra.add_child(this._relleno);
        this._barra.connect('notify::width', () => this._pintar());

        caja.add_child(cabecera);
        caja.add_child(this._barra);
        this.add_child(caja);
    }

    // Sin super.activate(): no se emite 'activate' y el menu sigue abierto.
    activate() {
        this._alActivar?.();
    }

    // pct null oculta la barra; expandido null oculta la flecha.
    fijar(texto, pct, expandido) {
        this._label.text = texto;
        this._barra.visible = pct !== null;
        this._fraccion = (pct ?? 0) / 100;
        this._flecha.visible = expandido !== null;
        this._flecha.iconName = expandido ? 'pan-down-symbolic' : 'pan-end-symbolic';
        this._pintar();
    }

    _pintar() {
        this._relleno.width = Math.round(this._barra.width * this._fraccion);
    }
});

const ModoToggle = GObject.registerClass(
class ModoToggle extends QuickMenuToggle {
    _init() {
        super._init({title: 'Juego', iconName: ICONO_JUEGO, toggleMode: false});

        this._iaActiva = false;
        this._ocupado = false;
        this._sincronizando = false;
        this._destruido = false;
        this._pctShaders = null;
        this._resumenShaders = '';
        this._juegos = [];
        this._subtituloVram = null;

        this.menu.setHeader(ICONO_JUEGO, 'Modo del equipo');

        this._itemJuego = new PopupMenu.PopupMenuItem('Juego');
        this._itemJuego.connect('activate', () => this._cambiar('modo-juego'));
        this.menu.addMenuItem(this._itemJuego);

        this._itemIa = new PopupMenu.PopupMenuItem('IA local (Ollama)');
        this._itemIa.connect('activate', () => this._cambiar('modo-ia'));
        this.menu.addMenuItem(this._itemIa);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        this._itemVisita = new PopupMenu.PopupSwitchMenuItem('Visita (audio por la tele)', false);
        // setToggleState tambien emite 'toggled': sin este filtro, refrescar el estado lanza el script.
        this._itemVisita.connect('toggled', (_item, activo) => {
            if (!this._sincronizando)
                this._cambiar('modo-visita', activo ? [] : ['off']);
        });
        this.menu.addMenuItem(this._itemVisita);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        this._itemVram = new PopupMenu.PopupMenuItem('VRAM: -', {reactive: false});
        this.menu.addMenuItem(this._itemVram);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        this._expandido = false;
        this._filasJuegos = [];
        this._filaShaders = new FilaProgreso(() => {
            this._expandido = !this._expandido;
            this._pintarShaders();
        });
        this.menu.addMenuItem(this._filaShaders);
        this._seccionJuegos = new PopupMenu.PopupMenuSection();
        this.menu.addMenuItem(this._seccionJuegos);

        this.connect('clicked', () => this._cambiar(this._iaActiva ? 'modo-juego' : 'modo-ia'));
        this.menu.connect('open-state-changed', (_menu, abierto) => {
            if (abierto) {
                this._refrescar();
                this._refrescarShaders();
            }
        });
        this.connect('destroy', () => {
            this._destruido = true;
            GLib.source_remove(this._timer);
            GLib.source_remove(this._timerShaders);
        });

        this._timerShaders = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, REFRESCO_SHADERS_SEG, () => {
            this._refrescarShaders();
            return GLib.SOURCE_CONTINUE;
        });
        this._refrescarShaders();

        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, REFRESCO_SEG, () => {
            this._refrescar();
            return GLib.SOURCE_CONTINUE;
        });
        this._refrescar();
    }

    async _cambiar(script, args = []) {
        if (this._ocupado)
            return;
        this._ocupado = true;
        this.subtitle = 'Cambiando...';

        const [ok, salida] = await ejecutar([GLib.build_filenamev([BIN, script]), ...args]);
        if (this._destruido)
            return;

        this._ocupado = false;
        const ultima = salida.split('\n').pop() || script;
        Main.notify(ok ? 'Modos' : `Modos: ${script} fallo`, ultima);
        await this._refrescar();
    }

    async _refrescar() {
        const [[iaActiva], [visita], [vramOk, vram]] = await Promise.all([
            ejecutar(['systemctl', 'is-active', '--quiet', 'ollama']),
            ejecutar([GLib.build_filenamev([BIN, 'modo-visita']), 'status']),
            ejecutar(['nvidia-smi', '--query-gpu=memory.used,memory.total',
                '--format=csv,noheader,nounits']),
        ]);
        if (this._destruido)
            return;

        this._iaActiva = iaActiva;
        this.checked = iaActiva;
        this.title = iaActiva ? 'IA local' : 'Juego';
        this.iconName = iaActiva ? ICONO_IA : ICONO_JUEGO;
        this.menu.setHeader(this.iconName, 'Modo del equipo');
        this._itemJuego.setOrnament(iaActiva ? PopupMenu.Ornament.NONE : PopupMenu.Ornament.CHECK);
        this._itemIa.setOrnament(iaActiva ? PopupMenu.Ornament.CHECK : PopupMenu.Ornament.NONE);
        this._sincronizando = true;
        this._itemVisita.setToggleState(visita);
        this._sincronizando = false;

        let textoVram = 'VRAM: -';
        if (vramOk) {
            const [usada, total] = vram.split('\n')[0].split(',').map(v => v.trim());
            textoVram = `VRAM: ${usada} / ${total} MiB`;
        }
        this._itemVram.label.text = textoVram;
        this._subtituloVram = vramOk ? textoVram.replace('VRAM: ', '') : null;
        this._pintarSubtitulo();
    }

    async _refrescarShaders() {
        const [activo, salida] = await ejecutar([GLib.build_filenamev([BIN, 'steam-shaders'])]);
        if (this._destruido)
            return;

        this._juegos = [];
        this._pctShaders = null;
        if (activo) {
            const [total, ...filas] = salida.split('\n').map(l => l.split('\t'));
            this._pctShaders = Number(total[1]);
            this._resumenShaders = `${total[2]}/${total[3]} juegos`;
            this._juegos = filas.map(([estado, pct, hechos, cuantos, nombre]) =>
                ({estado, pct: Number(pct), hechos, cuantos, nombre}));
        }
        this._pintarShaders();
        this._pintarSubtitulo();
    }

    _pintarShaders() {
        const activo = this._pctShaders !== null;
        this._filaShaders.fijar(
            activo ? `Shaders de Steam: ${this._pctShaders} % (${this._resumenShaders})` : 'Shaders de Steam: inactivo',
            this._pctShaders,
            activo ? this._expandido : null);

        const juegos = activo && this._expandido ? this._juegos : [];
        while (this._filasJuegos.length > juegos.length)
            this._filasJuegos.pop().destroy();
        while (this._filasJuegos.length < juegos.length) {
            const fila = new FilaProgreso(null, true);
            this._filasJuegos.push(fila);
            this._seccionJuegos.addMenuItem(fila);
        }
        juegos.forEach((j, i) => {
            let detalle = 'en cola';
            if (j.estado === 'listo')
                detalle = 'listo';
            else if (j.estado === 'comp')
                detalle = `${j.pct} % (${j.hechos}/${j.cuantos})`;
            this._filasJuegos[i].fijar(`${j.nombre}: ${detalle}`, j.pct, null);
        });
    }

    _pintarSubtitulo() {
        if (this._ocupado)
            return;
        this.subtitle = this._pctShaders !== null
            ? `Shaders ${this._pctShaders} %`
            : this._subtituloVram;
    }
});

const Indicador = GObject.registerClass(
class Indicador extends SystemIndicator {
    _init() {
        super._init();
        this.quickSettingsItems.push(new ModoToggle());
    }

    destroy() {
        this.quickSettingsItems.forEach(item => item.destroy());
        super.destroy();
    }
});

export default class ModosExtension extends Extension {
    enable() {
        this._indicador = new Indicador();
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicador);
    }

    disable() {
        this._indicador.destroy();
        this._indicador = null;
    }
}
