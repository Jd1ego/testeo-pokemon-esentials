import requests
import zipfile
import io
import os

# Configuración del repositorio
REPO = "Jd1ego/testeo-pokemon-esentials"
API_URL = f"https://api.github.com/repos/{REPO}/releases" # Quitamos "/latest" para obtener todos
PATCH_NAME = "patch.zip"
VERSION_FILE = "version.txt"

def get_local_version():
    if os.path.exists(VERSION_FILE):
        with open(VERSION_FILE, "r") as f:
            return f.read().strip()
    return None

def set_local_version(version):
    with open(VERSION_FILE, "w") as f:
        f.write(version)

def main():
    local_version = get_local_version()
    
    if not local_version:
        print(f"Error: No se encontró el archivo {VERSION_FILE}.")
        print("Por favor, descarga el juego completo desde GitHub la primera vez.")
        input("Presiona Enter para salir...")
        return

    print(f"Versión actual detectada: {local_version}")
    print("Conectando con GitHub para buscar actualizaciones...")
    
    try:
        # 1. Obtener la lista de todos los releases
        response = requests.get(API_URL)
        response.raise_for_status()
        releases = response.json()
        
        # 2. Filtrar y encontrar los releases que faltan
        pending_updates = []
        
        # La API de GitHub devuelve los releases desde el más nuevo al más viejo
        for release in releases:
            if release["tag_name"] == local_version:
                break # Llegamos a la versión que ya tiene el jugador
            if not release.get("draft"): # Ignoramos borradores
                pending_updates.append(release)
                
        if not pending_updates:
            print("¡Tu juego ya está en la última versión!")
            input("Presiona Enter para salir...")
            return
            
        # 3. Invertir la lista para instalarlos en orden cronológico (v1.1 -> v1.2 -> v1.3)
        pending_updates.reverse()
        
        print(f"\nSe encontraron {len(pending_updates)} actualización(es) pendiente(s).")
        
        # 4. Descargar y aplicar cada parche secuencialmente
        for release in pending_updates:
            tag = release["tag_name"]
            print(f"\n--- Aplicando actualización: {tag} ---")
            
            asset_url = next((a['browser_download_url'] for a in release.get('assets', []) if a['name'] == PATCH_NAME), None)
            
            if not asset_url:
                print(f"Advertencia: No se encontró '{PATCH_NAME}' en la versión {tag}.")
                print("Es posible que sea un release de juego completo. Saltando parche...")
                continue
                
            print("Descargando parche...")
            r = requests.get(asset_url, stream=True)
            r.raise_for_status()
            
            print("Instalando archivos...")
            with zipfile.ZipFile(io.BytesIO(r.content)) as z:
                z.extractall(os.getcwd())
                
            # Guardamos la versión actual tras cada parche exitoso
            # Así, si falla a la mitad o se cierra de golpe, no vuelve a descargar lo anterior
            set_local_version(tag)
            
        print("\n¡Juego actualizado a la última versión con éxito!")
        
    except requests.exceptions.RequestException as e:
        print(f"Error de red al conectar con GitHub: {e}")
    except Exception as e:
        print(f"Error durante la actualización: {e}")
        
    input("Presiona Enter para salir...")

if __name__ == "__main__":
    main()