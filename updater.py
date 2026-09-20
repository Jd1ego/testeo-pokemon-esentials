import requests
import zipfile
import io
import os

# Configuración del repositorio
REPO = "Jd1ego/testeo-pokemon-esentials"
API_URL = f"https://api.github.com/repos/{REPO}/releases/latest"
PATCH_NAME = "patch.zip"

def main():
    print("Conectando con el servidor para buscar actualizaciones...")
    try:
        response = requests.get(API_URL)
        response.raise_for_status()
        data = response.json()
        
        # Buscar la URL de descarga del patch.zip
        asset_url = next((asset['browser_download_url'] for asset in data.get('assets', []) if asset['name'] == PATCH_NAME), None)
        
        if not asset_url:
            print("Ya tienes la última versión o no hay un parche disponible en este momento.")
            input("Presiona Enter para salir...")
            return

        print(f"Descargando parche de la versión {data['tag_name']}...")
        r = requests.get(asset_url, stream=True)
        r.raise_for_status()
        
        # Extraer el zip en el directorio actual (raíz del juego)
        with zipfile.ZipFile(io.BytesIO(r.content)) as z:
            z.extractall(os.getcwd())
            
        print("¡Juego actualizado con éxito!")
        
    except requests.exceptions.RequestException as e:
        print(f"Error de red: {e}")
    except Exception as e:
        print(f"Error durante la actualización: {e}")
        
    input("Presiona Enter para salir...")

if __name__ == "__main__":
    main()