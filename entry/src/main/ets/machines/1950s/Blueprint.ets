import { MachineBlueprint } from '../BlueprintTypes';

/** 1950s 蓝图：值取自 docs/素材分层锚点表.md 的 1950s 实测节。 */
export const BLUEPRINT_1950: MachineBlueprint = {
  leverSizeRatio: 0.09,
  leverAspect: 0.09,
  bracketAspect: 0.87,
  bracketPivotX: 0.504,
  bracketPivotY: 0.427,
  rollerWidthRatio: 0.9528,
  leverPivotY: 0.942,
  bracketRawfile: (): Resource => $rawfile('layers/1950s-streamlined/lever-pivot-bracket.png'),
};