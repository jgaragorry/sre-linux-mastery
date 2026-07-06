#!/bin/bash
BUCKET_NAME="garagorry-sre-tfstate-global"

echo "🔥 [PURGA] Destruyendo Backend Remoto de iac-mastery_7..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "⏳ Eliminando objetos y versiones de manera recursiva..."
    aws s3 rm "s3://$BUCKET_NAME" --recursive || true
    aws s3 rb "s3://$BUCKET_NAME" --force || echo "⚠ Nota: Si hay Object Lock activo, el contenedor se mantendrá de forma gratuita hasta su expiración temporal."
else
    echo "✔ Nada que eliminar. El bucket no existe."
fi
