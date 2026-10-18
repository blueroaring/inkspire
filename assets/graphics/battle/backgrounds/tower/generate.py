"""Regenerate authored tower environment plates with the installed APINebula skill."""
import json
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parent
CLI = pathlib.Path.home() / '.codex/skills/apinebula-image/scripts/apinebula_image.js'
COMMON = ('Use case: game-asset. One finished premium hand-painted anime environment plate for a supernatural Chinese high-school card battle RPG. '
          'Wide 16:9 landscape, finely painted believable materials, cinematic light, dark atmospheric depth. '
          'No people, no creatures, no monsters, no silhouettes, no readable text, no UI, no watermark, no borders, no collage. '
          'Eye-level camera, broad open foreground floor and calm midground for enemy sprites at x=45-90%, y=25-65%. '
          'Architecture and thematic details concentrated on back wall and far edges; keep center spacious. ')
SCENES = {
 'ranking_ashes': 'An abandoned Chinese school classroom after the mock-exam ranking announcement. Rear bulletin boards hold rows of scorched paper sheets, edges glowing faint ember red; unreadable ruled marks only. Black ash floats around the edges, sunset burns through far-left windows. Desks pushed to the perimeter, empty polished wooden center floor. Charcoal, muted rust red and amber; an oppressive ceremonial atmosphere.',
 'magic_stage': 'The old school auditorium transformed into an intimate impossible magic stage. Tall plum velvet curtains frame an empty wooden stage, huge playing-card backs hover near the side wings, empty top hats and ribbon loops only at far edges, a few thin brass stage hoops. Soft violet and amber spotlights, deep maroon and midnight blue. A large unoccupied central performance space; no magician.',
 'infirmary': 'An abandoned school infirmary at night. Pale white privacy curtains half closed on both sides, empty narrow beds and medicine cupboards along edges, a school wall clock, cold tiled floor with muted green reflections. A long ominous gap between the rear curtains; restrained dark violet shadows behind the white fabric, cool clinical mint and pale lavender. No patient, no gore.',
 'sealed_auditorium': 'A tightly sealed school auditorium at night. Heavy wooden storage crates and stacked folded chairs tower at the far sides, converging inward. Far rear double doors locked with heavy chains, huge dark ceiling beams lower toward the room. Wide empty central wooden floor remains clear. Subdued dusty amber emergency lamps against dark desaturated indigo, claustrophobic perspective without covering the sprite area.',
 'perfect_score_hall': 'A surreal school examination classroom obsessed with perfect marks. Enormous circular brass grading seal and blank red-stamped papers on the back wall, repeated perfectly symmetrical rulers and compass circles, endless test sheets around the outer borders. No readable numerals or writing. Pale ivory chalk dust against deep blackboard teal, controlled harsh red grading accents, clear empty reflective classroom floor. Symmetry and rigid perfection, not a magical palace.',
 'thunder_discipline': 'The school disciplinary office and assembly hall fractured by a thunderstorm. Stern elevated empty wooden lectern on far rear wall, institutional windows, dark school notice boards with unreadable paper rectangles. Lightning illuminates huge storm clouds through broken upper windows; restrained gold-white arcs around pillars and blue slate interior. Large vacant foreground terrazzo floor, solemn oppressive school authority, no throne or deity.',
 'math_exam_hall': 'An impossible mathematics examination hall. Desks pushed far to left and right, very wide empty wooden floor. Back wall has an enormous deep green chalkboard with faint abstract curves and geometric chalk diagrams, no readable formulas or words. Floating translucent wireframe polyhedra and luminous cyan graph curves recede behind the board. Cool teal and chalk white with narrow warm window light. Academic pressure and inexhaustible mathematical depth.',
 'panic_silence': 'A deserted school corridor swallowed by suffocating silence. Closed dark classroom doors recede at either side, window panes and dangling bell cables form gentle throatlike converging arches above, thin black-red ribbons hang from ceiling edges. Cold desaturated indigo, dim sickly pearl light at the rear, wide clear dark floor. No literal anatomy; psychological panic and inability to speak.',
 'panic_gazes': 'The same deserted school corridor ruptures into a surreal theater of scrutiny. Many empty classroom windows and tilted mirrors line the upper rear wall in rows like watching eyes, subtle violet reflections in their panes, no literal faces or actual eyes. Taut red strings converge from the borders toward the upper vanishing point. Wide vacant floor with muted crimson reflections, deep plum-black and tarnished magenta, oppressive public ridicule.',
 'panic_island': 'The school corridor has dissolved into a solitary empty floor platform over a dark ink abyss. Bent school window frames and tall cage bars surround the distant perimeter, black ribbons join overhead like a closing cage. Lonely pale blue light falls on the broad unoccupied platform. Midnight navy and glacial pale cyan with faint wine-red cracks. Vast isolation and self-imprisonment, no figures, no buildings at center.',
 'inverse_injury': 'An abandoned school athletics rehabilitation room at stormy night. Cold tiled open floor, sports physiotherapy bench and unused crutches along far-left wall, off-white bandages hanging over distant gym bars and tracks looping along rear wall like old scars. Thin muted crimson light threads through the cracks in the floor at the edges. Slate gray, faded medical ivory, restrained dark red; aching memory of injuries, no gore or people.',
 'inverse_mirror': 'An impossible school training gym with a wall of fractured full-height mirrors. Broken reflections show empty rain-soaked running tracks and cyan lane lines folding into the distance, no reflected people. Jagged mirror shards at upper edges and far sides, broad clear reflective dark floor at center. Silver blue and cold white, sharp crimson limit lines along perimeter. Psychological confrontation with one self and athletic limits, elegant severe atmosphere.',
}

def generate(item):
    name, scene = item
    prompt = COMMON + scene
    prompt_file = ROOT / (name + '.prompt.txt')
    prompt_file.write_text(prompt, encoding='utf-8')
    output = ROOT / (name + '.png')
    if output.exists():
        return {'id': name, 'cached': True}
    args = ['node', str(CLI), '--prompt-file', str(prompt_file), '--output', str(output), '--size', '1536x864', '--quality', 'high', '--model', 'gpt-image-2', '--timeout', '300000']
    result = subprocess.run(args, capture_output=True, text=True, encoding='utf-8')
    if result.returncode and any(token in result.stderr for token in ['429', '500', '502', '503', '504']):
        time.sleep(8)
        result = subprocess.run(args, capture_output=True, text=True, encoding='utf-8')
    return {'id': name, 'code': result.returncode, 'result': result.stdout.strip(), 'error': result.stderr.strip()}

if __name__ == '__main__':
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / 'generation.json').write_text(json.dumps({'tool': 'APINebula skill CLI', 'model': 'gpt-image-2', 'prompts': {key: COMMON + scene for key, scene in SCENES.items()}}, ensure_ascii=False, indent=2), encoding='utf-8')
    # Stop a batch on a channel failure instead of repeating the same rejected request.
    for item in SCENES.items():
        result = generate(item)
        print(json.dumps(result, ensure_ascii=False), flush=True)
        if result.get('code'):
            raise SystemExit(1)
